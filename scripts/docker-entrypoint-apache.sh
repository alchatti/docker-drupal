#!/usr/bin/env bash
set -euo pipefail

# Shared runtime entrypoint for:
#   s6-fpm  -> Apache + PHP-FPM under s6-overlay
#   mod_php -> Apache foreground with mod_php
#
# Runtime Controls:
#   DRUPAL_RUNTIME_MODE: s6-fpm | mod_php
#   APP_ROOT: Drupal project root, default /app
#   DRUPAL_PUBLIC_DIR: web | docroot, default web
#   DOC_ROOT: optional absolute override for Drupal public docroot
#   PUBLIC_ROOT: Apache public root, default /var/www/html
#   DRUPAL_SUBDIR: optional URL subdirectory, e.g. test-site or /test-site
#
# Missing app fallback:
#   APP_MISSING_PLACEHOLDER=1
#   APP_MISSING_HTTP_STATUS=503
#   APP_MISSING_MESSAGE="Drupal application was not found..."
#
# Layout:
#   APP_ROOT=/app
#   DRUPAL_PUBLIC_DIR=web      -> DOC_ROOT=/app/web
#   DRUPAL_PUBLIC_DIR=docroot  -> DOC_ROOT=/app/docroot
#
#   DRUPAL_SUBDIR empty:
#     /var/www/html -> /app/web or /app/docroot
#
#   DRUPAL_SUBDIR=test-site:
#     /var/www/html/test-site -> /app/web or /app/docroot

: "${DRUPAL_RUNTIME_MODE:=s6-fpm}"

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

: "${APP_ROOT:=/app}"
: "${PUBLIC_ROOT:=/var/www/html}"
: "${DRUPAL_PUBLIC_DIR:=web}"
: "${DOC_ROOT:=}"
: "${DRUPAL_SUBDIR:=}"

: "${APP_MISSING_PLACEHOLDER:=1}"
: "${APP_MISSING_HTTP_STATUS:=503}"
: "${APP_MISSING_MESSAGE:=Drupal application was not found. Please mount or copy the application code into APP_ROOT and ensure DRUPAL_PUBLIC_DIR points to web or docroot.}"

: "${APACHE_CONFIG_DIR:=/_config/apache}"
: "${FPM_RUNTIME_CONF:=/usr/local/etc/php-fpm.d/zz-runtime.conf}"

: "${DEFAULT_MEMORY_LIMIT_MB:=1024}"
: "${USE_HOST_MEMORY_WHEN_UNLIMITED:=0}"
: "${RESERVED_MEMORY_MIN_MB:=128}"
: "${RESERVED_MEMORY_FRACTION:=10}"
: "${PHP_MEMORY_LIMIT_MIN_MB:=128}"
: "${PHP_MEMORY_LIMIT_MAX_MB:=768}"
: "${OPCACHE_MIN_MB:=96}"
: "${OPCACHE_MAX_MB:=256}"
: "${AVG_PHP_THREAD_MB:=120}"
: "${HEADROOM_MB:=64}"
: "${MIN_PHP_THREADS:=2}"
: "${MAX_PHP_THREADS_CAP:=256}"
: "${START_WORKERS:=2}"
: "${MIN_SPARE_WORKERS:=2}"
: "${MAX_SPARE_WORKERS:=10}"
: "${MAX_REQUESTS_PER_CHILD:=5000}"
: "${APACHE_WORKERS_MULTIPLIER:=4}"
: "${APACHE_MAX_REQUEST_WORKERS_CAP:=400}"

APACHE_RUNTIME_CONF="${APACHE_CONFIG_DIR}/drupal-runtime.conf"
APACHE_MPM_CONF="${APACHE_CONFIG_DIR}/apache-mpm.conf"

mkdir -p "${APACHE_CONFIG_DIR}"

clean_path_segment() {
    printf '%s' "$1" | sed 's|^/||;s|/$||'
}

safe_rm_rf() {
    local target="$1"

    case "${target}" in
        ""|"/"|"/app"|"/app/"|"/var"|"/var/"|"/var/www"|"/var/www/"|"${APP_ROOT}"|"${APP_ROOT}/"|"${DOC_ROOT}"|"${DOC_ROOT}/")
            echo "ERROR: Refusing to remove unsafe path: ${target}" >&2
            exit 1
            ;;
    esac

    rm -rf "${target}"
}

resolve_doc_root() {
    local public_dir

    public_dir="$(clean_path_segment "${DRUPAL_PUBLIC_DIR:-web}")"

    case "${public_dir}" in
        web|docroot)
            ;;
        *)
            echo "ERROR: Invalid DRUPAL_PUBLIC_DIR=${DRUPAL_PUBLIC_DIR}" >&2
            echo "Allowed values: web, docroot" >&2
            exit 1
            ;;
    esac

    if [ -z "${DOC_ROOT}" ]; then
        DOC_ROOT="${APP_ROOT}/${public_dir}"
    fi

    if [[ "${APP_ROOT}" != /* ]]; then
        echo "ERROR: APP_ROOT must be an absolute path. Current value: ${APP_ROOT}" >&2
        exit 1
    fi

    if [[ "${DOC_ROOT}" != /* ]]; then
        echo "ERROR: DOC_ROOT must be an absolute path. Current value: ${DOC_ROOT}" >&2
        exit 1
    fi

    if [[ "${PUBLIC_ROOT}" != /* ]]; then
        echo "ERROR: PUBLIC_ROOT must be an absolute path. Current value: ${PUBLIC_ROOT}" >&2
        exit 1
    fi

    export DOC_ROOT
}

create_missing_app_index() {
    if [ -f "${DOC_ROOT}/index.php" ]; then
        return
    fi

    if [ "${APP_MISSING_PLACEHOLDER}" != "1" ]; then
        echo "[system-init] WARNING: Drupal index.php was not found under: ${DOC_ROOT}"
        echo "[system-init] APP_MISSING_PLACEHOLDER is disabled; no fallback index.php will be created."
        return
    fi

    echo "[system-init] Drupal index.php was not found under: ${DOC_ROOT}"
    echo "[system-init] Creating fallback missing-application page: ${DOC_ROOT}/index.php"

    cat > "${DOC_ROOT}/index.php" <<'PHP_MISSING_APP'
<?php

$status = (int) (getenv('APP_MISSING_HTTP_STATUS') ?: 503);

if ($status < 100 || $status > 599) {
    $status = 503;
}

$message = getenv('APP_MISSING_MESSAGE') ?: 'Drupal application was not found.';

http_response_code($status);
header('Content-Type: text/plain; charset=UTF-8');
header('X-Drupal-Runtime: missing-application');

echo $message . PHP_EOL;
echo PHP_EOL;
echo 'APP_ROOT=' . (getenv('APP_ROOT') ?: '/app') . PHP_EOL;
echo 'DRUPAL_PUBLIC_DIR=' . (getenv('DRUPAL_PUBLIC_DIR') ?: 'web') . PHP_EOL;
echo 'DOC_ROOT=' . (getenv('DOC_ROOT') ?: '') . PHP_EOL;
PHP_MISSING_APP

    chmod 0644 "${DOC_ROOT}/index.php"
}

prepare_public_root() {
    local clean_subdir="$1"
    local mount_path

    if [ ! -d "${DOC_ROOT}" ]; then
        echo "[system-init] Drupal docroot does not exist yet. Creating: ${DOC_ROOT}"
        mkdir -p "${DOC_ROOT}"
    fi

    create_missing_app_index

    mkdir -p "$(dirname "${PUBLIC_ROOT}")"

    if [ -n "${clean_subdir}" ]; then
        if [[ ! "${clean_subdir}" =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "ERROR: Invalid DRUPAL_SUBDIR=${DRUPAL_SUBDIR}" >&2
            echo "Allowed characters: letters, numbers, dot, underscore and hyphen." >&2
            exit 1
        fi

        echo "[system-init] Mounting Drupal docroot ${DOC_ROOT} at /${clean_subdir}"

        if [ -L "${PUBLIC_ROOT}" ] || [ -f "${PUBLIC_ROOT}" ]; then
            safe_rm_rf "${PUBLIC_ROOT}"
        fi

        mkdir -p "${PUBLIC_ROOT}"

        mount_path="${PUBLIC_ROOT}/${clean_subdir}"
        safe_rm_rf "${mount_path}"
        ln -sfn "${DOC_ROOT}" "${mount_path}"

        echo "[system-init] Symlink created: ${mount_path} -> ${DOC_ROOT}"
    else
        echo "[system-init] Mounting Drupal docroot ${DOC_ROOT} at root"

        safe_rm_rf "${PUBLIC_ROOT}"
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

CLEAN_SUBDIR="$(clean_path_segment "${DRUPAL_SUBDIR}")"
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

echo "[system-init] Runtime initialization complete."
echo "[system-init] APP_ROOT=${APP_ROOT}"
echo "[system-init] DRUPAL_PUBLIC_DIR=${DRUPAL_PUBLIC_DIR}"
echo "[system-init] DOC_ROOT=${DOC_ROOT}"
echo "[system-init] PUBLIC_ROOT=${PUBLIC_ROOT}"
echo "[system-init] DRUPAL_SUBDIR=${CLEAN_SUBDIR:-<root>}"
echo "[system-init] Handing control over to: $*"

exec "$@"
