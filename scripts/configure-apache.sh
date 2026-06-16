#!/usr/bin/env bash
set -euo pipefail

# configure-apache-runtime.sh
#
# Reusable Apache runtime setup.
#
# Designed for both:
# - php:*apache images
# - custom Apache + PHP-FPM images
#
# This script intentionally does NOT configure:
# - PHP ini files
# - PHP_INI_SCAN_DIR
# - PHP-FPM pools
# - mod_php
# - s6 services
#
# Configurable environment variables:
#   APACHE_PORT=8080
#   APP_ROOT=/var/www/html
#   DOC_ROOT=/var/www/html/web
#   CONFIG_DIR=/_config
#   FILES_DIR=/mnt/files
#   APACHE_USER=www-data
#   APACHE_GROUP=www-data

set -x

APACHE_PORT="${APACHE_PORT:-8080}"
APP_ROOT="${APP_ROOT:-/var/www/html}"
DOC_ROOT="${DOC_ROOT:-/var/www/html/web}"
CONFIG_DIR="${CONFIG_DIR:-/_config}"
FILES_DIR="${FILES_DIR:-/mnt/files}"
APACHE_USER="${APACHE_USER:-www-data}"
APACHE_GROUP="${APACHE_GROUP:-www-data}"

APACHE_PORTS_CONF="${APACHE_PORTS_CONF:-/etc/apache2/ports.conf}"
APACHE_DEFAULT_SITE="${APACHE_DEFAULT_SITE:-/etc/apache2/sites-available/000-default.conf}"
APACHE_MAIN_CONF="${APACHE_MAIN_CONF:-/etc/apache2/apache2.conf}"

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

# Change Apache listen port from 80 to the configured unprivileged port.
sed -i "s/^Listen 80$/Listen ${APACHE_PORT}/g" "${APACHE_PORTS_CONF}"

# Change default VirtualHost port.
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:${APACHE_PORT}>/g" "${APACHE_DEFAULT_SITE}"

# Set Drupal-style document root.
sed -i "s|/var/www/html|${DOC_ROOT}|g" "${APACHE_DEFAULT_SITE}"

# Create shared runtime config directory.
mkdir -p "${CONFIG_DIR}"

touch \
    "${CONFIG_DIR}/apache-mpm.conf" \
    "${CONFIG_DIR}/drupal-runtime.conf"

# Add optional Apache includes only once.
grep -qxF "IncludeOptional ${CONFIG_DIR}/apache-mpm.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${CONFIG_DIR}/apache-mpm.conf" >> "${APACHE_MAIN_CONF}"

grep -qxF "IncludeOptional ${CONFIG_DIR}/drupal-runtime.conf" "${APACHE_MAIN_CONF}" \
    || echo "IncludeOptional ${CONFIG_DIR}/drupal-runtime.conf" >> "${APACHE_MAIN_CONF}"

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
    "${CONFIG_DIR}" \
    "${FILES_DIR}" \
    /etc/apache2

chmod -R 755 "${FILES_DIR}"
