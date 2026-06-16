#!/usr/bin/env bash
set -euo pipefail

echo "[system-init] Starting Drupal Container Initialization (Apache mod_php Non-Root Runtime Mode)"

FIRST_ARG="${1:-}"

if [ -z "${FIRST_ARG}" ]; then
    set -- apache2-foreground
    FIRST_ARG="apache2-foreground"
fi

if [ "${FIRST_ARG}" != "apache2-foreground" ]; then
    echo "[system-init] Bypassing webserver initialization to run standalone command: $*"
    exec "$@"
fi

# --- Runtime config locations ---
CONFIG_ROOT="${CONFIG_ROOT:-/_config}"
APACHE_CONFIG_DIR="${APACHE_CONFIG_DIR:-${CONFIG_ROOT}/apache}"
PHP_CONFIG_DIR="${PHP_CONFIG_DIR:-${CONFIG_ROOT}/php}"

APACHE_RUNTIME_CONF="${APACHE_CONFIG_DIR}/drupal-runtime.conf"
APACHE_MPM_CONF="${APACHE_CONFIG_DIR}/apache-mpm.conf"
PHP_RUNTIME_INI="${PHP_CONFIG_DIR}/zz-runtime.ini"

mkdir -p "${APACHE_CONFIG_DIR}" "${PHP_CONFIG_DIR}"

# --- Tuning knobs with production defaults ---
: "${MEM_FRACTION_FOR_PHP:=0.70}"
: "${PHP_MEMORY_LIMIT_FRACTION:=0.25}"
: "${OPCACHE_FRACTION_OF_PHP:=0.30}"
: "${AVG_PHP_THREAD_MB:=85}"
: "${MIN_PHP_THREADS:=4}"
: "${MAX_PHP_THREADS_CAP:=256}"
: "${PHP_MAX_ACCEL_FILES:=50000}"
: "${PHP_VALIDATE_TIMESTAMPS:=0}"

# Apache tuning for mod_php prefork
: "${APACHE_START_SERVERS:=2}"
: "${APACHE_MIN_SPARE_SERVERS:=2}"
: "${APACHE_MAX_SPARE_SERVERS:=10}"
: "${APACHE_MAX_CONNECTIONS_PER_CHILD:=5000}"

# App details
: "${DRUPAL_ROOT:=/var/www/html/web}"
: "${DRUPAL_SITE_URL:=http://127.0.0.1}"

# --- Subdirectory routing ---
if [ -n "${DRUPAL_SUBDIR:-}" ]; then
    CLEAN_SUBDIR="$(echo "${DRUPAL_SUBDIR}" | sed 's|^/||;s|/$||')"

    echo "[system-init] Activating Apache Alias for subdirectory: /${CLEAN_SUBDIR}"

    cat > "${APACHE_RUNTIME_CONF}" <<EOF
Alias /${CLEAN_SUBDIR} ${DRUPAL_ROOT}

<Directory ${DRUPAL_ROOT}>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF
else
    echo "[system-init] Operating at root domain level."
    : > "${APACHE_RUNTIME_CONF}"
fi

# --- Cgroup memory detection ---
get_mem_limit_mb() {
    local bytes="0"

    if [ -f /sys/fs/cgroup/memory.max ]; then
        bytes="$(cat /sys/fs/cgroup/memory.max)"
        if [ "${bytes}" = "max" ]; then
            bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
        fi
    elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        bytes="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"
    else
        bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
    fi

    echo "${bytes}" | awk '{printf "%.0f", $1 / 1024 / 1024}'
}

TOTAL_MB="$(get_mem_limit_mb)"

# Fallback to safe 1GB profile if value is outside expected container range.
if [ "${TOTAL_MB}" -lt 128 ] || [ "${TOTAL_MB}" -gt 32768 ]; then
    TOTAL_MB=1024
fi

export TOTAL_MB

PHP_BUDGET_MB="$(php -r '
$total = (int) getenv("TOTAL_MB");
$phpFrac = (float) (getenv("MEM_FRACTION_FOR_PHP") ?: "0.70");
echo max(128, floor($total * $phpFrac));
')"

export PHP_BUDGET_MB

PHP_MEMORY_LIMIT_MB="$(php -r '
$budget = (int) getenv("PHP_BUDGET_MB");
$frac = (float) (getenv("PHP_MEMORY_LIMIT_FRACTION") ?: "0.25");
echo max(128, min(1024, floor($budget * $frac)));
')"

OPCACHE_MB="$(php -r '
$budget = (int) getenv("PHP_BUDGET_MB");
$frac = (float) (getenv("OPCACHE_FRACTION_OF_PHP") ?: "0.30");
echo min(1024, max(64, floor($budget * $frac)));
')"

HEADROOM_MB=64

MAX_PHP_THREADS="$(( (PHP_BUDGET_MB - OPCACHE_MB - HEADROOM_MB) / AVG_PHP_THREAD_MB ))"

if [ "${MAX_PHP_THREADS}" -lt "${MIN_PHP_THREADS}" ]; then
    MAX_PHP_THREADS="${MIN_PHP_THREADS}"
fi

if [ "${MAX_PHP_THREADS}" -gt "${MAX_PHP_THREADS_CAP}" ]; then
    MAX_PHP_THREADS="${MAX_PHP_THREADS_CAP}"
fi

APACHE_MRW="${MAX_PHP_THREADS}"

echo "[system-init] Profile auto-tuned: TOTAL=${TOTAL_MB}MB | PHP_BUDGET=${PHP_BUDGET_MB}MB | memory_limit=${PHP_MEMORY_LIMIT_MB}M | opcache=${OPCACHE_MB}M | apache_max_workers=${APACHE_MRW}"

# --- PHP runtime config ---
TZ_SETTING=""

if [ -n "${TZ:-}" ]; then
    TZ_SETTING="date.timezone=${TZ}"
fi

cat > "${PHP_RUNTIME_INI}" <<EOF
memory_limit=${PHP_MEMORY_LIMIT_MB}M
opcache.memory_consumption=${OPCACHE_MB}
opcache.max_accelerated_files=${PHP_MAX_ACCEL_FILES}
opcache.validate_timestamps=${PHP_VALIDATE_TIMESTAMPS}
${TZ_SETTING}
EOF

# --- Apache prefork runtime config ---
cat > "${APACHE_MPM_CONF}" <<EOF
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

echo "[system-init] Runtime configuration finalized. Starting Apache."

exec "$@"
