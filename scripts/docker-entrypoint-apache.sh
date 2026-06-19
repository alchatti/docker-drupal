#!/usr/bin/env bash
set -euo pipefail

# Shared runtime entrypoint for both image variants:
#   s6-fpm  -> Apache + PHP-FPM under s6-overlay
#   mod_php -> Apache foreground with mod_php

if [ -n "${DRUPAL_RUNTIME_MODE:-}" ]; then
    RUNTIME_MODE="${DRUPAL_RUNTIME_MODE}"
elif [ -x /init ] && [ -d /etc/s6-overlay ]; then
    RUNTIME_MODE="s6-fpm"
else
    RUNTIME_MODE="mod_php"
fi

case "${RUNTIME_MODE}" in
    s6-fpm)
        DEFAULT_COMMAND="/init"
        echo "[system-init] Starting Drupal container: Apache + PHP-FPM + s6-overlay"
        ;;
    mod_php)
        DEFAULT_COMMAND="apache2-foreground"
        echo "[system-init] Starting Drupal container: Apache mod_php"
        ;;
    *)
        echo "ERROR: Unsupported DRUPAL_RUNTIME_MODE=${RUNTIME_MODE}" >&2
        exit 1
        ;;
esac

FIRST_ARG="${1:-}"
if [ -z "${FIRST_ARG}" ]; then
    set -- "${DEFAULT_COMMAND}"
    FIRST_ARG="${DEFAULT_COMMAND}"
fi

if [ "${FIRST_ARG}" != "apache2-foreground" ] && [ "${FIRST_ARG}" != "/init" ]; then
    echo "[system-init] Bypassing webserver initialization to run command: $*"
    exec "$@"
fi

CONFIG_ROOT="${CONFIG_ROOT:-/_config}"
APACHE_CONFIG_DIR="${APACHE_CONFIG_DIR:-${CONFIG_ROOT}/apache}"
PHP_CONFIG_DIR="${PHP_CONFIG_DIR:-${CONFIG_ROOT}/php}"
FPM_RUNTIME_CONF="${FPM_RUNTIME_CONF:-/usr/local/etc/php-fpm.d/zz-runtime.conf}"

APACHE_RUNTIME_CONF="${APACHE_CONFIG_DIR}/drupal-runtime.conf"
APACHE_MPM_CONF="${APACHE_CONFIG_DIR}/apache-mpm.conf"
PHP_RUNTIME_INI="${PHP_CONFIG_DIR}/zz-runtime.ini"

mkdir -p "${APACHE_CONFIG_DIR}" "${PHP_CONFIG_DIR}"

: "${MEM_FRACTION_FOR_PHP:=0.70}"
: "${PHP_MEMORY_LIMIT_FRACTION:=0.25}"
: "${OPCACHE_FRACTION_OF_PHP:=0.30}"
: "${AVG_PHP_THREAD_MB:=85}"
: "${MIN_PHP_THREADS:=4}"
: "${MAX_PHP_THREADS_CAP:=256}"
: "${PHP_MAX_ACCEL_FILES:=50000}"
: "${PHP_VALIDATE_TIMESTAMPS:=0}"

: "${START_WORKERS:=2}"
: "${MIN_SPARE_WORKERS:=2}"
: "${MAX_SPARE_WORKERS:=10}"
: "${MAX_REQUESTS_PER_CHILD:=5000}"
: "${APACHE_MAX_REQUEST_WORKERS:=400}"

: "${DOC_ROOT:=/var/www/html/web}"
: "${DRUPAL_ROOT:=${DOC_ROOT}}"

if [ -n "${DRUPAL_SUBDIR:-}" ]; then
    CLEAN_SUBDIR="$(echo "${DRUPAL_SUBDIR}" | sed 's|^/||;s|/$||')"
    echo "[system-init] Activating Apache Alias for subdirectory: /${CLEAN_SUBDIR}"

    cat > "${APACHE_RUNTIME_CONF}" <<EOF_ALIAS
Alias /${CLEAN_SUBDIR} ${DRUPAL_ROOT}

<Directory ${DRUPAL_ROOT}>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF_ALIAS
else
    echo "[system-init] Operating at root domain level."
    : > "${APACHE_RUNTIME_CONF}"
fi

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

# Docker can report very large host memory when no limit is set. Use a safe default.
if [ "${TOTAL_MB}" -lt 128 ] || [ "${TOTAL_MB}" -gt 262144 ]; then
    TOTAL_MB=1024
fi

export TOTAL_MB MEM_FRACTION_FOR_PHP PHP_MEMORY_LIMIT_FRACTION OPCACHE_FRACTION_OF_PHP

PHP_BUDGET_MB="$(php -r '
$total = (int) getenv("TOTAL_MB");
$phpFrac = (float) (getenv("MEM_FRACTION_FOR_PHP") ?: "0.70");
echo max(128, (int) floor($total * $phpFrac));
')"
export PHP_BUDGET_MB

PHP_MEMORY_LIMIT_MB="$(php -r '
$budget = (int) getenv("PHP_BUDGET_MB");
$frac = (float) (getenv("PHP_MEMORY_LIMIT_FRACTION") ?: "0.25");
echo max(128, min(1024, (int) floor($budget * $frac)));
')"

OPCACHE_MB="$(php -r '
$budget = (int) getenv("PHP_BUDGET_MB");
$frac = (float) (getenv("OPCACHE_FRACTION_OF_PHP") ?: "0.30");
echo min(1024, max(64, (int) floor($budget * $frac)));
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

echo "[system-init] Auto-tuned profile (${RUNTIME_MODE}): TOTAL=${TOTAL_MB}MB | PHP_BUDGET=${PHP_BUDGET_MB}MB | memory_limit=${PHP_MEMORY_LIMIT_MB}M | opcache=${OPCACHE_MB}M | workers=${MAX_WORKERS}"

TZ_SETTING=""
if [ -n "${TZ:-}" ]; then
    TZ_SETTING="date.timezone=${TZ}"
fi

cat > "${PHP_RUNTIME_INI}" <<EOF_INI
memory_limit=${PHP_MEMORY_LIMIT_MB}M
opcache.memory_consumption=${OPCACHE_MB}
opcache.max_accelerated_files=${PHP_MAX_ACCEL_FILES}
opcache.validate_timestamps=${PHP_VALIDATE_TIMESTAMPS}
${TZ_SETTING}
EOF_INI

if [ "${RUNTIME_MODE}" = "s6-fpm" ]; then
    cat > "${FPM_RUNTIME_CONF}" <<EOF_FPM
[www]
pm = dynamic
pm.start_servers = ${START_WORKERS}
pm.min_spare_servers = ${MIN_SPARE_WORKERS}
pm.max_spare_servers = ${MAX_SPARE_WORKERS}
pm.max_children = ${MAX_WORKERS}
pm.max_requests = ${MAX_REQUESTS_PER_CHILD}
clear_env = no
catch_workers_output = yes
decorate_workers_output = no
EOF_FPM

    cat > "${APACHE_MPM_CONF}" <<EOF_APACHE_EVENT
ServerTokens Prod
ServerSignature Off

<IfModule mpm_event_module>
    StartServers             ${START_WORKERS}
    MinSpareThreads          25
    MaxSpareThreads          75
    ThreadLimit              64
    ThreadsPerChild          25
    MaxRequestWorkers        ${APACHE_MAX_REQUEST_WORKERS}
    MaxConnectionsPerChild   ${MAX_REQUESTS_PER_CHILD}
</IfModule>
EOF_APACHE_EVENT
else
    cat > "${APACHE_MPM_CONF}" <<EOF_APACHE_PREFORK
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
EOF_APACHE_PREFORK
fi

echo "[system-init] Runtime initialization complete. Handing control over to: $*"
exec "$@"
