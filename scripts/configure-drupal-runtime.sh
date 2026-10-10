#!/usr/bin/env bash
set -euo pipefail

# Build-time Apache/PHP layout for Drupal.
# Assumes required defaults are supplied by Dockerfile ENV.
# This script must never start Apache, PHP-FPM, s6, /init, or exec "$@".

set -x

PHP_CONF_DIR="/usr/local/etc/php/conf.d"

APACHE_PORTS_CONF="/etc/apache2/ports.conf"
APACHE_DEFAULT_SITE="/etc/apache2/sites-available/000-default.conf"
APACHE_MAIN_CONF="/etc/apache2/apache2.conf"
APACHE_SECURITY_CONF="/etc/apache2/conf-available/security.conf"

: "${APP_ROOT:=/app}"
: "${PUBLIC_ROOT:=/var/www/html}"

mkdir -p \
    "${APP_ROOT}" \
    "${PUBLIC_ROOT}" \
    "${APACHE_CONFIG_DIR}" \
    "${PHP_CONF_DIR}" \
    "${FILES_DIR}/public" \
    "${FILES_DIR}/private" \
    "${FILES_DIR}/tmp" \
    "${FILES_DIR}/config/sync" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /var/run/php

touch \
    "${APACHE_CONFIG_DIR}/apache-mpm.conf" \
    "${APACHE_CONFIG_DIR}/drupal-runtime.conf"

# DRUPAL_SUBDIR is handled by runtime symlinks.
a2enmod rewrite expires headers

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    a2dismod mpm_prefork || true
    a2enmod mpm_event proxy proxy_fcgi setenvif
elif [ "${DRUPAL_RUNTIME_MODE}" = "mod_php" ]; then
    a2dismod mpm_event || true
    a2enmod mpm_prefork
else
    echo "ERROR: Unsupported DRUPAL_RUNTIME_MODE=${DRUPAL_RUNTIME_MODE}" >&2
    exit 1
fi

cat > "${APACHE_PORTS_CONF}" <<EOF_PORTS
Listen ${APACHE_PORT}
EOF_PORTS

PHP_HANDLER=""

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    PHP_HANDLER=$(cat <<EOF_HANDLER

    <FilesMatch \.php$>
        SetHandler "proxy:unix:${FPM_SOCKET}|fcgi://localhost/"
    </FilesMatch>
EOF_HANDLER
)
fi

cat > "${APACHE_DEFAULT_SITE}" <<EOF_VHOST
<VirtualHost *:${APACHE_PORT}>
    ServerName localhost
    DocumentRoot ${PUBLIC_ROOT}
    DirectoryIndex index.php index.html

    <Directory ${PUBLIC_ROOT}>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>${PHP_HANDLER}

    ErrorLog /proc/self/fd/2
    CustomLog /proc/self/fd/1 combined
</VirtualHost>
EOF_VHOST

grep -qxF "ServerName localhost" "${APACHE_MAIN_CONF}" \
    || echo "ServerName localhost" >> "${APACHE_MAIN_CONF}"

grep -qxF "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" >> "${APACHE_MAIN_CONF}"

if [ -f "${APACHE_SECURITY_CONF}" ]; then
    sed -i 's/^ServerTokens .*/ServerTokens Prod/g' "${APACHE_SECURITY_CONF}"
    sed -i 's/^ServerSignature .*/ServerSignature Off/g' "${APACHE_SECURITY_CONF}"
fi

cat > "${PHP_CONF_DIR}/docker-php-drupal-recommended.ini" <<'EOF_INI'
memory_limit=${PHP_MEMORY_LIMIT}
output_buffering=${PHP_OUTPUT_BUFFERING}
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}
post_max_size=${PHP_POST_MAX_SIZE}
max_execution_time=${PHP_MAX_EXECUTION_TIME}
max_input_vars=${PHP_MAX_INPUT_VARS}
realpath_cache_size=${PHP_REALPATH_CACHE_SIZE}
realpath_cache_ttl=${PHP_REALPATH_CACHE_TTL}
date.timezone=${TZ}

opcache.enable=${PHP_OPCACHE_ENABLE}
opcache.enable_cli=${PHP_OPCACHE_ENABLE_CLI}
opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}
opcache.interned_strings_buffer=${PHP_OPCACHE_INTERNED_STRINGS_BUFFER}
opcache.max_accelerated_files=${PHP_OPCACHE_MAX_ACCEL_FILES}
opcache.validate_timestamps=${PHP_OPCACHE_VALIDATE_TIMESTAMPS}
opcache.revalidate_freq=${PHP_OPCACHE_REVALIDATE_FREQ}
EOF_INI

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    cat > /usr/local/etc/php-fpm.d/zz-docker.conf <<EOF_FPM_SOCKET
[global]
daemonize = no

[www]
; user/group are intentionally empty: PHP-FPM inherits the master process
; identity (www-data) so no privilege drop occurs in the rootless s6 setup.
user =
group =
listen = ${FPM_SOCKET}
listen.owner = ${APACHE_RUN_USER}
listen.group = ${APACHE_RUN_GROUP}
listen.mode = 0660
clear_env = no
catch_workers_output = yes
decorate_workers_output = no
EOF_FPM_SOCKET

    touch "${FPM_RUNTIME_CONF}"
fi

chown -R "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" \
    "${APP_ROOT}" \
    /var/www \
    "${CONFIG_ROOT}" \
    "${FILES_DIR}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /var/run/php \
    /etc/apache2

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    chown "${APACHE_RUN_USER}:${APACHE_RUN_GROUP}" \
        "${FPM_RUNTIME_CONF}" \
        /usr/local/etc/php-fpm.d/zz-docker.conf
fi

chmod -R 755 "${CONFIG_ROOT}" "${APP_ROOT}" /etc/apache2
chmod -R 775 "${FILES_DIR}" /var/run/php /var/run/apache2 /var/lock/apache2 /var/log/apache2
