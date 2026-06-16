#!/bin/bash
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: Pipeline returns the exit status of the last command to fail.
set -euo pipefail

echo "[system-init] Starting Drupal Container Initialization (Non-Root Runtime Mode)"

# --- 1. Intercept CLI Commands and Skip Web Server Configuration ---
# Safely capture the first argument even if it's completely empty (prevents unbound variable errors)
FIRST_ARG="${1:-}"

if [ "$FIRST_ARG" != 'apache2-foreground' ]; then
    echo "[system-init] Bypassing webserver initialization to run standalone command: $*"
    exec "$@"
fi

# --- 2. Tuning Knobs with Production Defaults ---
: "${MEM_FRACTION_FOR_PHP:=0.70}"
: "${PHP_MEMORY_LIMIT_FRACTION:=0.25}"
: "${OPCACHE_FRACTION_OF_PHP:=0.30}"
: "${AVG_PHP_THREAD_MB:=85}"
: "${MIN_PHP_THREADS:=4}"
: "${MAX_PHP_THREADS_CAP:=256}"
: "${PHP_MAX_ACCEL_FILES:=50000}"
: "${PHP_VALIDATE_TIMESTAMPS:=0}"

# Apache Tuning (Optimized for Prefork Process Model)
: "${APACHE_START_SERVERS:=2}"
: "${APACHE_MIN_SPARE_SERVERS:=2}"
: "${APACHE_MAX_SPARE_SERVERS:=10}"
: "${APACHE_MAX_CONNECTIONS_PER_CHILD:=5000}"

# App Details
: "${DRUPAL_ROOT:=/var/www/html/web}"
: "${DRUPAL_SITE_URL:=http://127.0.0.1}"

# --- 3. Handle Subsite vs Root Level Routing ---
RUNTIME_SUBDIR_CONFIG="/_config/drupal-runtime.conf"
if [ -n "${DRUPAL_SUBDIR:-}" ]; then
    CLEAN_SUBDIR=$(echo "${DRUPAL_SUBDIR}" | sed 's|^/||;s|/$||')
    echo "[system-init] Activating Apache Alias for subdirectory: /${CLEAN_SUBDIR}"
    cat <<EOF > "$RUNTIME_SUBDIR_CONFIG"
Alias /${CLEAN_SUBDIR} /var/www/html/web
<Directory /var/www/html/web>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
else
    echo "[system-init] Operating at root domain level."
    > "$RUNTIME_SUBDIR_CONFIG"
fi

# --- 4. Dynamic Cgroup Memory Calculations ---
get_mem_limit_mb() {
  local bytes="0"
  if [[ -f /sys/fs/cgroup/memory.max ]]; then
    bytes=$(cat /sys/fs/cgroup/memory.max)
    [[ "$bytes" == "max" ]] && bytes=$(awk '/MemTotal/ {print $2*1024}' /proc/meminfo)
  elif [[ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]]; then
    bytes=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
  else
    bytes=$(awk '/MemTotal/ {print $2*1024}' /proc/meminfo)
  fi
  echo "$bytes" | awk '{printf "%.0f", $1/1024/1024}'
}

TOTAL_MB=$(get_mem_limit_mb)
# Fallback to safe 1GB profile if values leak out of sensible boundaries
[[ "$TOTAL_MB" -lt 128 || "$TOTAL_MB" -gt 32768 ]] && TOTAL_MB=1024
export TOTAL_MB

PHP_BUDGET_MB=$(php -r "
\$total = (int)getenv('TOTAL_MB');
\$php_frac = (float)(getenv('MEM_FRACTION_FOR_PHP') ?: '0.70');
echo max(128, floor(\$total * \$php_frac));
")
export PHP_BUDGET_MB

PHP_MEMORY_LIMIT_MB=$(php -r "
\$budget = (int)getenv('PHP_BUDGET_MB');
\$frac = (float)(getenv('PHP_MEMORY_LIMIT_FRACTION') ?: '0.25');
echo max(128, min(1024, floor(\$budget * \$frac)));
")

OPCACHE_MB=$(php -r "
\$budget = (int)getenv('PHP_BUDGET_MB');
\$frac = (float)(getenv('OPCACHE_FRACTION_OF_PHP') ?: '0.30');
echo min(1024, max(64, floor(\$budget * \$frac)));
")

# Calculate concurrent request handling worker thresholds based on real memory constraints
HEADROOM_MB=64
MAX_PHP_THREADS=$(( (PHP_BUDGET_MB - OPCACHE_MB - HEADROOM_MB) / AVG_PHP_THREAD_MB ))
(( MAX_PHP_THREADS < MIN_PHP_THREADS )) && MAX_PHP_THREADS=$MIN_PHP_THREADS
(( MAX_PHP_THREADS > MAX_PHP_THREADS_CAP )) && MAX_PHP_THREADS=$MAX_PHP_THREADS_CAP

# For mpm_prefork, MaxRequestWorkers determines total concurrent web processes allowed
APACHE_MRW=$MAX_PHP_THREADS

echo "[system-init] Profile Auto-tuned: TOTAL=${TOTAL_MB}MB | PHP_BUDGET=${PHP_BUDGET_MB}MB | memory_limit=${PHP_MEMORY_LIMIT_MB}M | opcache=${OPCACHE_MB}M | apache_max_workers=${APACHE_MRW}"

# --- 5. Write Runtime Files to Writable /_config Directory ---

# Generate PHP adjustments (Mapped to PHP_INI_SCAN_DIR via Dockerfile)
TZ_SETTING=""
if [[ -n "${TZ:-}" ]]; then
  TZ_SETTING="date.timezone=${TZ}"
fi

cat > /_config/zz-www.ini << EOF
memory_limit=${PHP_MEMORY_LIMIT_MB}M
opcache.memory_consumption=${OPCACHE_MB}
opcache.max_accelerated_files=${PHP_MAX_ACCEL_FILES}
opcache.validate_timestamps=${PHP_VALIDATE_TIMESTAMPS}
${TZ_SETTING}
EOF

# Generate Core Apache Worker Layout configurations targeting mpm_prefork
cat > /_config/apache-mpm.conf << EOF
# Security Headers
ServerTokens Prod
ServerSignature Off

<IfModule mpm_prefork_module>
    StartServers             ${APACHE_START_SERVERS}
    MinSpareServers          ${APACHE_MIN_SPARE_SERVERS}
    MaxSpareServers          ${APACHE_MAX_SPARE_SERVERS}
    ServerLimit              ${APACHE_MRW}
    MaxRequestWorkers        ${APACHE_MRW}
    MaxConnectionsPerChild   ${APACHE_MAX_CONNECTIONS_PER_CHILD}
</IfModule>
EOF

echo "[system-init] Real-time calculations finalized. Handing command over to Apache executable."

# Execute core webserver process safely
exec "$@"
