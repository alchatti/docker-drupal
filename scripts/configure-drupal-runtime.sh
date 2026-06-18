#!/usr/bin/env bash
set -euo pipefail

# configure-drupal-runtime.sh
#
# Shared Drupal runtime setup for ROOTLESS Apache + PHP-FPM images
# Handles environment variable injection inside a rootless container.

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
if command -v a2enmod >/dev/null 2>&1; then
    a2enmod rewrite alias expires
fi

# Change Apache listen port from 80 to the configured unprivileged port.
sed -i "s/^Listen 80$/Listen ${APACHE_PORT}/g" "${APACHE_PORTS_CONF}"

# Change default VirtualHost port from 80 to the configured port.
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${APACHE_PORT}>/g" "${APACHE_DEFAULT_SITE}"

# Set Drupal-style document root.
sed -i "s|/var/www/html|${DOC_ROOT}|g" "${APACHE_DEFAULT_SITE}"

# Create Apache and PHP config directories using brace expansion
mkdir -p "${CONFIG_ROOT}/{apache,php}"

touch \
    "${APACHE_CONFIG_DIR}/apache-mpm.conf" \
    "${APACHE_CONFIG_DIR}/drupal-runtime.conf"

# Add optional Apache include directory only once (Using echo to extend)
grep -qxF "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${APACHE_CONFIG_DIR}/*.conf" >> "${APACHE_MAIN_CONF}"

# Custom Drupal Production & Runtime Engine optimizations
cat << 'EOF' > "${PHP_CONFIG_DIR}/docker-php-drupal-recommended.ini"
output_buffering=true
memory_limit=256M
upload_max_filesize=64M
post_max_size=64M
max_execution_time=120
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0
opcache.revalidate_freq=60
EOF

# Create Drupal persistent/runtime directories using brace expansion
mkdir -p "${FILES_DIR}/{public,private,tmp,config/sync}"

# Ensure APP_ROOT (/var/www/html) and Apache runtime directories exist
mkdir -p \
    "${APP_ROOT}" \
    /var/{run,lock,log}/apache2

# ==============================================================================
# Rootless Ownership and Permissions Allocation
# ==============================================================================

# Explicitly ensure everything belongs to www-data so the rootless engine can 
# modify configs, rewrite logs, and manage sockets at boot.
chown -R "${APACHE_USER}:${APACHE_GROUP}" \
    "${APP_ROOT}" \
    "${CONFIG_ROOT}" \
    "${FILES_DIR}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /etc/apache2

# Permissions layout:
# Allow www-data complete control inside its assigned directories 
chmod -R 755 "${CONFIG_ROOT}"
chmod -R 755 "${APP_ROOT}"
chmod -R 755 /etc/apache2

# Give Drupal assets and Apache locks fully open group permissions if mapped volume scaling is needed
chmod -R 775 "${FILES_DIR}"
