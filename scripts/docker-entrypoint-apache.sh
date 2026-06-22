#!/usr/bin/env bash
set -euo pipefail

# Shared runtime entrypoint for:
#   s6-fpm  -> Apache + PHP-FPM under s6-overlay
#   mod_php -> Apache foreground with mod_php
#
# Runtime controls:
#   DRUPAL_RUNTIME_MODE: s6-fpm | mod_php
#   APP_ROOT:            Drupal project root. Default: /app
#   DRUPAL_PUBLIC_DIR:   Drupal public directory under APP_ROOT. Allowed: web | docroot
#   DOC_ROOT:            Optional absolute override for Drupal public directory
#   PUBLIC_ROOT:         Apache public root. Default: /var/www/html
#   DRUPAL_SUBDIR:       Optional URL subdirectory, for example test-site

case "${DRUPAL_RUNTIME_MODE}" in
    s6-fpm)
        DEFAULT_COMMAND="/init"
        echo "[system-init] Starting Drupal container: Apache + PHP-FPM + s6-overlay"
        ;;
    mod_php)
        DEFAULT_COMMAND="apache2-foreground"
        echo "[system-init] Starting Drupal container: Apache mod_php"
        ;;
    *)
        echo "ERROR: Unsupported DRUPAL_RUNTIME_MODE=${DRUPAL_RUNTIME_MODE}" >&2
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

APACHE_RUNTIME_CONF="${APACHE_CONFIG_DIR}/drupal-runtime.conf"
APACHE_MPM_CONF="${APACHE_CONFIG_DIR}/apache-mpm.conf"

: "${APP_ROOT:=/app}"
: "${PUBLIC_ROOT:=/var/www/html}"
: "${DRUPAL_PUBLIC_DIR:=web}"

mkdir -p "${APACHE_CONFIG_DIR}"

resolve_doc_root() {
    local public_dir

    public_dir="${DRUPAL_PUBLIC_DIR:-web}"
    public_dir="$(echo "${public_dir}" | sed 's|^/||;s|/$||')"

    case "${public_dir}" in
        web|docroot)
            ;;
        *)
            echo "ERROR: Invalid DRUPAL_PUBLIC_DIR=${DRUPAL_PUBLIC_DIR}" >&2
            echo "Allowed values: web, docroot" >&2
            exit 1
            ;;
    esac

    if [ -z "${DOC_ROOT:-}" ]; then
        DOC_ROOT="${APP_ROOT}/${public_dir}"
    fi

    if [[ "${DOC_ROOT}" != /* ]]; then
        echo "ERROR: DOC_ROOT must be an absolute path. Current value: ${DOC_ROOT}" >&2
        exit 1
    fi

    export DOC_ROOT
}

prepare_public_root() {
    local clean_subdir="${1:-}"

    if [ ! -d "${DOC_ROOT}" ]; then
        echo "ERROR: Drupal docroot does not exist: ${DOC_ROOT}" >&2
        echo "Check APP_ROOT=${APP_ROOT} and DRUPAL_PUBLIC_DIR=${DRUPAL_PUBLIC_DIR}" >&2
        exit 1
    fi

    if [ ! -f "${DOC_ROOT}/index.php" ]; then
        echo "ERROR: Drupal index.php was not found under: ${DOC_ROOT}" >&2
        echo "This does not look like a valid Drupal public directory." >&2
        exit 1
    fi

    mkdir -p "$(dirname "${PUBLIC_ROOT}")"

    if [ -n "${clean_subdir}" ]; then
        if [[ ! "${clean_subdir}" =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "ERROR: Invalid DRUPAL_SUBDIR=${DRUPAL_SUBDIR}" >&2
            echo "Allowed characters: letters, numbers, dot, underscore and hyphen." >&2
            exit 1
        fi

        echo "[system-init] Mounting Drupal docroot ${DOC_ROOT} at /${clean_subdir}"

        rm -rf "${PUBLIC_ROOT}"
        mkdir -p "${PUBLIC_ROOT}"
        ln -sfn "${DOC_ROOT}" "${PUBLIC_ROOT}/${clean_subdir}"

        echo "[system-init] Symlink created: ${PUBLIC_ROOT}/${clean_subdir} -> ${DOC_ROOT}"
    else
        echo "[system-init] Mounting Drupal docroot ${DOC_ROOT} at root"

        rm -rf "${PUBLIC_ROOT}"
        ln -sfn "${DOC_ROOT}" "${PUBLIC_ROOT}"

        echo "[system-init] Symlink created: ${PUBLIC_ROOT} -> ${DOC_ROOT}"
    fi

    cat > "${APACHE_RUNTIME_CONF}" <<EOF_RUNTIME
<Directory ${DOC_ROOT}>
    Options FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
EOF_RUNTIME
}

resolve_doc_root

CLEAN_SUBDIR="$(echo "${DRUPAL_SUBDIR:-}" | sed 's|^/||;s|/$||')"
prepare_public_root "${CLEAN_SUBDIR}"

get_mem_limit_mb() {
    local bytes="0"

    if [ -f /sys/fs/cgroup/memory.max ]; then
        bytes="$(cat /sys/fs/cgroup/memory.max)"

        if [ "${bytes}" = "max" ]; then
            if [ "${USE_HOST_MEMORY_WHEN_UNLIMITED}" = "1" ]; then
                bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
            else
                echo "${DEFAULT_MEMORY_LIMIT_MB}"
                return
            fi
        fi

    elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        bytes="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)"

        if [ "${bytes}" -gt 281474976710656 ] 2>/dev/null; then
            if [ "${USE_HOST_MEMORY_WHEN_UNLIMITED}" = "1" ]; then
                bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
            else
                echo "${DEFAULT_MEMORY_LIMIT_MB}"
                return
            fi
        fi
    else
        if [ "${USE_HOST_MEMORY_WHEN_UNLIMITED}" = "1" ]; then
            bytes="$(awk '/MemTotal/ {print $2 * 1024}' /proc/meminfo)"
        else
            echo "${DEFAULT_MEMORY_LIMIT_MB}"
            return
        fi
    fi

    echo "${bytes}" | awk '{printf "%.0f", $1 / 1024 / 1024}'
}

TOTAL_MB="$(get_mem_limit_mb)"

if [ "${TOTAL_MB}" -lt 128 ] || [ "${TOTAL_MB}" -gt 262144 ]; then
    TOTAL_MB="${DEFAULT_MEMORY_LIMIT_MB}"
fi

RESERVED_MB="$(( TOTAL_MB / RESERVED_MEMORY_FRACTION ))"

if [ "${RESERVED_MB}" -lt "${RESERVED_MEMORY_MIN_MB}" ]; then
    RESERVED_MB="${RESERVED_MEMORY_MIN_MB}"
fi

PHP_BUDGET_MB="$(( TOTAL_MB - RESERVED_MB ))"

if [ "${PHP_BUDGET_MB}" -lt 128 ]; then
    PHP_BUDGET_MB=128
fi

PHP_MEMORY_LIMIT_MB="$(( PHP_BUDGET_MB / 4 ))"

if [ "${PHP_MEMORY_LIMIT_MB}" -lt "${PHP_MEMORY_LIMIT_MIN_MB}" ]; then
    PHP_MEMORY_LIMIT_MB="${PHP_MEMORY_LIMIT_MIN_MB}"
fi

if [ "${PHP_MEMORY_LIMIT_MB}" -gt "${PHP_MEMORY_LIMIT_MAX_MB}" ]; then
    PHP_MEMORY_LIMIT_MB="${PHP_MEMORY_LIMIT_MAX_MB}"
fi

OPCACHE_MB="$(( TOTAL_MB / 8 ))"

if [ "${OPCACHE_MB}" -lt "${OPCACHE_MIN_MB}" ]; then
    OPCACHE_MB="${OPCACHE_MIN_MB}"
fi

if [ "${OPCACHE_MB}" -gt "${OPCACHE_MAX_MB}" ]; then
    OPCACHE_MB="${OPCACHE_MAX_MB}"
fi

AVAILABLE_FOR_WORKERS_MB="$(( PHP_BUDGET_MB - OPCACHE_MB - HEADROOM_MB ))"

if [ "${AVAILABLE_FOR_WORKERS_MB}" -lt "${AVG_PHP_THREAD_MB}" ]; then
    MAX_PHP_THREADS=1
else
    MAX_PHP_THREADS="$(( AVAILABLE_FOR_WORKERS_MB / AVG_PHP_THREAD_MB ))"
fi

if [ "${MAX_PHP_THREADS}" -lt "${MIN_PHP_THREADS}" ]; then
    MAX_PHP_THREADS="${MIN_PHP_THREADS}"
fi

if [ "${MAX_PHP_THREADS}" -gt "${MAX_PHP_THREADS_CAP}" ]; then
    MAX_PHP_THREADS="${MAX_PHP_THREADS_CAP}"
fi

MAX_WORKERS="${MAX_PHP_THREADS}"

APACHE_MAX_REQUEST_WORKERS="$(( MAX_WORKERS * APACHE_WORKERS_MULTIPLIER ))"

if [ "${APACHE_MAX_REQUEST_WORKERS}" -lt 25 ]; then
    APACHE_MAX_REQUEST_WORKERS=25
fi

if [ "${APACHE_MAX_REQUEST_WORKERS}" -gt "${APACHE_MAX_REQUEST_WORKERS_CAP}" ]; then
    APACHE_MAX_REQUEST_WORKERS="${APACHE_MAX_REQUEST_WORKERS_CAP}"
fi

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    if [ "${START_WORKERS}" -gt "${MAX_WORKERS}" ]; then
        START_WORKERS="${MAX_WORKERS}"
    fi

    if [ "${MIN_SPARE_WORKERS}" -gt "${MAX_WORKERS}" ]; then
        MIN_SPARE_WORKERS="${MAX_WORKERS}"
    fi

    if [ "${MAX_SPARE_WORKERS}" -gt "${MAX_WORKERS}" ]; then
        MAX_SPARE_WORKERS="${MAX_WORKERS}"
    fi

    if [ "${START_WORKERS}" -lt "${MIN_SPARE_WORKERS}" ]; then
        START_WORKERS="${MIN_SPARE_WORKERS}"
    fi

    if [ "${MAX_SPARE_WORKERS}" -lt "${START_WORKERS}" ]; then
        MAX_SPARE_WORKERS="${START_WORKERS}"
    fi
fi

export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT_MB}M"
export PHP_OPCACHE_MEMORY_CONSUMPTION="${OPCACHE_MB}"

echo "[system-init] Auto-tuned profile (${DRUPAL_RUNTIME_MODE}): TOTAL=${TOTAL_MB}MB | RESERVED=${RESERVED_MB}MB | PHP_BUDGET=${PHP_BUDGET_MB}MB | PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT} | PHP_OPCACHE_MEMORY_CONSUMPTION=${PHP_OPCACHE_MEMORY_CONSUMPTION} | php_workers=${MAX_WORKERS} | apache_workers=${APACHE_MAX_REQUEST_WORKERS}"

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
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
