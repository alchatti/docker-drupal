#!/usr/bin/env bash
set -euo pipefail

# Determine the runtime variant dynamically
if [ -x /init ] && [ -d /etc/s6-overlay ]; then
    RUNTIME_MODE="s6-fpm"
    DEFAULT_COMMAND="/init"
    echo "[system-init] Starting Drupal Container Initialization (Apache + PHP-FPM s6-overlay Mode)"
else
    RUNTIME_MODE="mod_php"
    DEFAULT_COMMAND="apache2-foreground"
    echo "[system-init] Starting Drupal Container Initialization (Apache mod_php Prefork Mode)"
fi

FIRST_ARG="${1:-}"

# Assign appropriate fallback execution targets based on the active flavor
if [ -z "${FIRST_ARG}" ]; then
    set -- ${DEFAULT_COMMAND}
    FIRST_ARG="${DEFAULT_COMMAND}"
fi

# Bypass setup if running isolated workspace/one-off tasks (drush, bash, etc.)
if [ "${FIRST_ARG}" != "apache2-foreground" ] && [ "${FIRST_ARG}" != "/init" ]; then
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
FPM_RUNTIME_CONF="${PHP_CONFIG_DIR}/zz-fpm-runtime.conf"

mkdir -p "${CONFIG_ROOT}/{apache,php}"

# --- Tuning knobs with production defaults ---
: "${MEM_FRACTION_FOR_PHP:=0.70}"
: "${PHP_MEMORY_LIMIT_FRACTION:=0.25}"
: "${OPCACHE_FRACTION_OF_PHP:=0.30}"
: "${AVG_PHP_THREAD_MB:=85}"
: "${MIN_PHP_THREADS:=4}"
: "${MAX_PHP_THREADS_CAP:=256}"
: "${PHP_MAX_ACCEL_FILES:=50000}"
: "${PHP_VALIDATE_TIMESTAMPS:=0}"

# Apache / FPM Worker Pooling Parameters
: "${START_WORKERS:=2}"
: "${MIN_SPARE_WORKERS:=2}"
: "${MAX_SPARE_WORKERS:=10}"
: "${MAX_REQUESTS_PER_CHILD:=5000}"

# App details
: "${DRUPAL_ROOT:=/var/www/html/web}"
: "${DRUPAL_SITE_URL:=http://127.0.0.1}"

# --- Subdirectory routing ---
if [ -n "${DRUPAL_SUBDIR:-}" ]; then
    CLEAN_SUBDIR="$(echo "${DRUPAL_SUBDIR}" | sed 's|^/||;s|/$||')"
    echo "[system-init] Activating Apache Alias for subdirectory: /${CLEAN_SUBDIR}"

    cat << EOF > "${APACHE_RUNTIME_CONF}"
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

MAX_WORKERS="${MAX_PHP_THREADS}"
echo "[system-init] Auto-tuned profile (${RUNTIME_MODE}): TOTAL=${TOTAL_MB}MB | PHP_BUDGET=${PHP_BUDGET_MB}MB | memory_limit=${PHP_MEMORY_LIMIT_MB}M | max_workers=${MAX_WORKERS}"

# --- Global PHP settings ---
TZ_SETTING=""
if [ -n "${TZ:-}" ]; then
    TZ_SETTING="date.timezone=${TZ}"
fi

cat << EOF > "${PHP_RUNTIME_INI}"
memory_limit=${PHP_MEMORY_LIMIT_MB}M
opcache.memory_consumption=${OPCACHE_MB}
opcache.max_accelerated_files=${PHP_MAX_ACCEL_FILES}
opcache.validate_timestamps=${PHP_VALIDATE_TIMESTAMPS}
${TZ_SETTING}
EOF

# --- Engine Specific Configuration Dispatcher ---
if [ "${RUNTIME_MODE}" = "s6-fpm" ]; then
    # 1. PHP-FPM dynamic pool management
    cat << EOF > "${FPM_RUNTIME_CONF}"
[www]
pm = dynamic
pm.start_servers = ${START_WORKERS}
pm.min_spare_servers = ${MIN_SPARE_WORKERS}
pm.max_spare_servers = ${MAX_SPARE_WORKERS}
pm.max_children = ${MAX_WORKERS}
pm.max_requests = ${MAX_REQUESTS_PER_CHILD}
EOF

    # 2. Apache MPM Event configuration for FPM proxy layout
    cat << EOF > "${APACHE_MPM_CONF}"
ServerTokens Prod
ServerSignature Off

<IfModule mpm_event_module>
    StartServers             ${START_WORKERS}
    MinSpareThreads          25
    MaxSpareThreads          75
    ThreadLimit              64
    ThreadsPerChild          25
    MaxRequestWorkers        400
    MaxConnectionsPerChild   ${MAX_REQUESTS_PER_CHILD}
</IfModule>
EOF

else
    # 3. Fallback Legacy Apache Prefork layout for mod_php
    : > "${FPM_RUNTIME_CONF}"
    cat << EOF > "${APACHE_MPM_CONF}"
ServerTokens Prod
ServerSignature Off

<IfModule mpm_prefork_module>
    StartServers             ${START_WORKERS}
    MinSpareServers          ${MIN_SPARE_WORKERS}
    MaxSpareServers          ${MAX_SPARE_WORKERS}
    ServerLimit              ${MAX_WORKERS}
    MaxRequestWorkers        ${MAX_WORKERS}
    MaxConnectionsPerChild   ${MAX_REQUESTS_PER_CHILD}
</IfModule>
EOF
fi

echo "[system-init] Runtime initialization complete. Handing control over to: $*"
exec "$@"
