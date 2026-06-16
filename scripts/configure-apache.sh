#!/usr/bin/env bash
set -euo pipefail

# configure-apache.sh
#
# Reusable Apache + Drupal runtime configuration script.
#
# Handles:
# - Apache non-root port change: 80 -> 8080
# - Drupal document root: /var/www/html/web
# - Runtime config include directory: /_config
# - Drupal persistent file directories
# - PHP recommended runtime ini files
# - Apache runtime directories for non-root execution
# - Ownership for www-data execution
#
# Intended for Debian-based official php:*apache images.

set -x

APACHE_PORT="${APACHE_PORT:-8080}"
APP_ROOT="${APP_ROOT:-/var/www/html}"
DOC_ROOT="${DOC_ROOT:-/var/www/html/web}"
APACHE_USER="${APACHE_RUN_USER:-www-data}"
APACHE_GROUP="${APACHE_RUN_GROUP:-www-data}"

CONFIG_DIR="${CONFIG_DIR:-/_config}"
FILES_DIR="${FILES_DIR:-/mnt/files}"

APACHE_PORTS_CONF="${APACHE_PORTS_CONF:-/etc/apache2/ports.conf}"
APACHE_DEFAULT_SITE="${APACHE_DEFAULT_SITE:-/etc/apache2/sites-available/000-default.conf}"
APACHE_MAIN_CONF="${APACHE_MAIN_CONF:-/etc/apache2/apache2.conf}"

PHP_CONF_DIR="${PHP_CONF_DIR:-/usr/local/etc/php/conf.d}"

if [ ! -f "${APACHE_PORTS_CONF}" ]; then
    echo "ERROR: Apache ports config not found: ${APACHE_PORTS_CONF}"
    exit 1
fi

if [ ! -f "${APACHE_DEFAULT_SITE}" ]; then
    echo "ERROR: Apache default site config not found: ${APACHE_DEFAULT_SITE}"
    exit 1
fi

if [ ! -f "${APACHE_MAIN_CONF}" ]; then
    echo "ERROR: Apache main config not found: ${APACHE_MAIN_CONF}"
    exit 1
fi

# 1. Shift Apache from privileged port 80 to unprivileged port.
sed -i "s/^Listen 80$/Listen ${APACHE_PORT}/g" "${APACHE_PORTS_CONF}"
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${APACHE_PORT}>/g" "${APACHE_DEFAULT_SITE}"

# 2. Update Apache DocumentRoot from /var/www/html to /var/www/html/web.
sed -i "s|/var/www/html|${DOC_ROOT}|g" "${APACHE_DEFAULT_SITE}"

# 3. Create internal config engine layouts.
mkdir -p "${CONFIG_DIR}"

touch \
    "${CONFIG_DIR}/apache-mpm.conf" \
    "${CONFIG_DIR}/drupal-runtime.conf"

# Add Apache optional includes only once.
grep -qxF "IncludeOptional ${CONFIG_DIR}/apache-mpm.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${CONFIG_DIR}/apache-mpm.conf" >> "${APACHE_MAIN_CONF}"

grep -qxF "IncludeOptional ${CONFIG_DIR}/drupal-runtime.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${CONFIG_DIR}/drupal-runtime.conf" >> "${APACHE_MAIN_CONF}"

# 4. Create Drupal persistent directories.
mkdir -p \
    "${FILES_DIR}/public" \
    "${FILES_DIR}/private" \
    "${FILES_DIR}/tmp" \
    "${FILES_DIR}/config/sync"

# 5. Recommended PHP.ini settings.
mkdir -p "${PHP_CONF_DIR}"

{
    echo 'opcache.memory_consumption=128'
    echo 'opcache.interned_strings_buffer=8'
    echo 'opcache.max_accelerated_files=4000'
    echo 'opcache.revalidate_freq=60'
} > "${PHP_CONF_DIR}/opcache-recommended.ini"

{
    echo 'output_buffering=true'
} > "${PHP_CONF_DIR}/docker-php-drupal-recommended.ini"

# 6. Ensure Apache runtime directories exist.
mkdir -p \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2

# 7. Standardize ownership for non-root Apache execution.
chown -R "${APACHE_USER}:${APACHE_GROUP}" \
    "${APP_ROOT}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    "${CONFIG_DIR}" \
    "${FILES_DIR}" \
    /etc/apache2

chmod -R 755 "${FILES_DIR}"
