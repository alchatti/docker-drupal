#!/usr/bin/env bash
set -euo pipefail

# configure-drupal-runtime.sh
#
# Shared Drupal runtime setup for:
# - php:*apache images
# - custom Apache + PHP-FPM images
#
# Handles:
# - Apache port change to non-root port 8080
# - Apache DocumentRoot to /var/www/html/web
# - Apache modules: rewrite, alias, expires
# - Apache runtime include directory: /_config/apache/*.conf
# - PHP runtime ini directory: /_config/php/*.ini
# - Recommended PHP ini settings
# - Drupal persistent file directories
# - Apache runtime directories
# - Ownership for non-root Apache execution
#
# This script intentionally does NOT configure:
# - PHP-FPM pools
# - Apache proxy_fcgi / SetHandler
# - mod_php-specific settings
# - s6 services

set -x

APACHE_PORT="${APACHE_PORT:-8080}"
APP_ROOT="${APP_ROOT:-/var/www/html}"
DOC_ROOT="${DOC_ROOT:-/var/www/html/web}"

CONFIG_ROOT="${CONFIG_ROOT:-/_config}"
APACHE_CONFIG_DIR="${APACHE_CONFIG_DIR:-${CONFIG_ROOT}/apache}"
PHP_CONFIG_DIR="${PHP_CONFIG_DIR:-${CONFIG_ROOT}/php}"

FILES_DIR="${FILES_DIR:-/mnt/files}"

APACHE_USER="${APACHE_USER:-www-data}"
APACHE_GROUP="${APACHE_GROUP:-www-data}"

APACHE_PORTS_CONF="${APACHE_PORTS_CONF:-/etc/apache2/ports.conf}"
APACHE_DEFAULT_SITE="${APACHE_DEFAULT_SITE:-/etc/apache2/sites-available/000-default.conf}"
APACHE_MAIN_CONF="${APACHE_MAIN_CONF:-/etc/apache2/apache2.conf}"

# Enable common Apache modules used by Drupal.
# Note: Apache module name is "expires", not "expire".
if command -v a2enmod >/dev/null 2>&1; then
    a2enmod rewrite alias expires
fi

# Change Apache listen port from 80 to the configured unprivileged port.
sed -i "s/^Listen 80$/Listen ${APACHE_PORT}/g" "${APACHE_PORTS_CONF}"

# Change default VirtualHost port from 80 to the configured port.
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${APACHE_PORT}>/g" "${APACHE_DEFAULT_SITE}"

# Set Drupal-style document root.
sed -i "s|/var/www/html|${DOC_ROOT}|g" "${APACHE_DEFAULT_SITE}"

# Create Apache and PHP config directories.
mkdir -p \
    "${APACHE_CONFIG_DIR}" \
    "${PHP_CONFIG_DIR}"

touch \
    "${APACHE_CONFIG_DIR}/apache-mpm.conf" \
    "${APACHE_CONFIG_DIR}/drupal-runtime.conf"

# Add optional Apache include directory only once.
grep -qxF "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" >> "${APACHE_MAIN_CONF}"

# Recommended PHP runtime settings.
{
    echo 'opcache.memory_consumption=128'
    echo 'opcache.interned_strings_buffer=8'
    echo 'opcache.max_accelerated_files=4000'
    echo 'opcache.revalidate_freq=60'
} > "${PHP_CONFIG_DIR}/opcache-recommended.ini"

{
    echo 'output_buffering=true'
} > "${PHP_CONFIG_DIR}/docker-php-drupal-recommended.ini"

# Create Drupal persistent/runtime directories.
mkdir -p \
    "${FILES_DIR}/public" \
    "${FILES_DIR}/private" \
    "${FILES_DIR}/tmp" \
    "${FILES_DIR}/config/sync"

# Ensure Apache runtime directories exist.
mkdir -p \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2

# Standardize ownership for non-root Apache execution.
chown -R "${APACHE_USER}:${APACHE_GROUP}" \
    "${APP_ROOT}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    "${CONFIG_ROOT}" \
    "${FILES_DIR}" \
    /etc/apache2

chmod -R 755 "${FILES_DIR}"
