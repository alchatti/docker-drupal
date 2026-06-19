#!/usr/bin/env bash
set -euo pipefail

# Build-time Apache/PHP layout for Drupal.
# Works for both:
#   DRUPAL_RUNTIME_MODE=s6-fpm  -> Apache event MPM + proxy_fcgi + PHP-FPM socket
#   DRUPAL_RUNTIME_MODE=mod_php -> Apache prefork + mod_php

set -x

DRUPAL_RUNTIME_MODE="${DRUPAL_RUNTIME_MODE:-auto}"
APACHE_PORT="${APACHE_PORT:-8080}"
APP_ROOT="${APP_ROOT:-/var/www/html}"
DOC_ROOT="${DOC_ROOT:-/var/www/html/web}"

CONFIG_ROOT="${CONFIG_ROOT:-/_config}"
APACHE_CONFIG_DIR="${APACHE_CONFIG_DIR:-${CONFIG_ROOT}/apache}"
PHP_CONFIG_DIR="${PHP_CONFIG_DIR:-${CONFIG_ROOT}/php}"
FPM_RUNTIME_CONF="${FPM_RUNTIME_CONF:-/usr/local/etc/php-fpm.d/zz-runtime.conf}"
FPM_SOCKET="${FPM_SOCKET:-/var/run/php/php-fpm.sock}"

FILES_DIR="${FILES_DIR:-/mnt/files}"

APACHE_USER="${APACHE_USER:-www-data}"
APACHE_GROUP="${APACHE_GROUP:-www-data}"

APACHE_PORTS_CONF="${APACHE_PORTS_CONF:-/etc/apache2/ports.conf}"
APACHE_DEFAULT_SITE="${APACHE_DEFAULT_SITE:-/etc/apache2/sites-available/000-default.conf}"
APACHE_MAIN_CONF="${APACHE_MAIN_CONF:-/etc/apache2/apache2.conf}"
APACHE_SECURITY_CONF="${APACHE_SECURITY_CONF:-/etc/apache2/conf-available/security.conf}"

mkdir -p \
    "${APP_ROOT}" \
    "${DOC_ROOT}" \
    "${APACHE_CONFIG_DIR}" \
    "${PHP_CONFIG_DIR}" \
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

if command -v a2enmod >/dev/null 2>&1; then
    a2enmod rewrite alias expires headers

    if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
        a2dismod mpm_prefork || true
        a2enmod mpm_event proxy proxy_fcgi setenvif
    elif [ "${DRUPAL_RUNTIME_MODE}" = "mod_php" ]; then
        a2dismod mpm_event || true
        a2enmod mpm_prefork
    fi
fi

cat > "${APACHE_PORTS_CONF}" <<EOF_PORTS
Listen ${APACHE_PORT}
EOF_PORTS

PHP_HANDLER=""
if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    PHP_HANDLER=$(cat <<EOF_HANDLER

    <FilesMatch \\.php$>
        SetHandler "proxy:unix:${FPM_SOCKET}|fcgi://localhost/"
    </FilesMatch>
EOF_HANDLER
)
fi

cat > "${APACHE_DEFAULT_SITE}" <<EOF_VHOST
<VirtualHost *:${APACHE_PORT}>
    ServerName localhost
    DocumentRoot ${DOC_ROOT}
    DirectoryIndex index.php index.html

    <Directory ${DOC_ROOT}>
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

cat > "${PHP_CONFIG_DIR}/docker-php-drupal-recommended.ini" <<'EOF_INI'
output_buffering=true
upload_max_filesize=64M
post_max_size=64M
max_execution_time=120
max_input_vars=4000
realpath_cache_size=4096K
realpath_cache_ttl=600
opcache.enable=1
opcache.enable_cli=1
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=50000
opcache.validate_timestamps=0
opcache.revalidate_freq=60
EOF_INI

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    cat > /usr/local/etc/php-fpm.d/zz-docker-socket.conf <<EOF_FPM_SOCKET
[www]
listen = ${FPM_SOCKET}
listen.owner = ${APACHE_USER}
listen.group = ${APACHE_GROUP}
listen.mode = 0660
EOF_FPM_SOCKET
    touch "${FPM_RUNTIME_CONF}"
fi

chown -R "${APACHE_USER}:${APACHE_GROUP}" \
    "${APP_ROOT}" \
    "${CONFIG_ROOT}" \
    "${FILES_DIR}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /var/run/php \
    /etc/apache2

if [ "${DRUPAL_RUNTIME_MODE}" = "s6-fpm" ]; then
    chown "${APACHE_USER}:${APACHE_GROUP}" "${FPM_RUNTIME_CONF}" /usr/local/etc/php-fpm.d/zz-docker-socket.conf
fi

chmod -R 755 "${CONFIG_ROOT}" "${APP_ROOT}" /etc/apache2
chmod -R 775 "${FILES_DIR}" /var/run/php /var/run/apache2 /var/lock/apache2 /var/log/apache2
