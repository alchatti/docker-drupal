#!/bin/bash
set -euo pipefail

# install-drupal-php-extensions.sh
#
# Intended for Debian/Ubuntu-based PHP images that include:
# - apt-get
# - docker-php-ext-configure
# - docker-php-ext-install
#
# Example:
#   chmod +x install-drupal-php-extensions.sh
#   ./install-drupal-php-extensions.sh

set -x

# Enable Apache modules if this is an Apache-based PHP image
if command -v a2enmod >/dev/null 2>&1; then
    a2enmod expires rewrite
fi

# Save currently manually installed packages
savedAptMark="$(apt-mark showmanual)"

apt-get update

apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev

docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg=/usr \
    --with-webp

docker-php-ext-install -j "$(nproc)" \
    gd \
    pdo_mysql \
    pdo_pgsql \
    zip

# Reset apt-mark's "manual" list so purge --auto-remove
# can remove build dependencies safely
apt-mark auto '.*' >/dev/null

# shellcheck disable=SC2086
apt-mark manual $savedAptMark

# Mark runtime library dependencies as manual so they are not removed
ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ {
        so = $(NF-1)
        if (index(so, "/usr/local/") == 1) {
            next
        }
        gsub("^/(usr/)?", "", so)
        printf "*%s\n", so
    }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

rm -rf /var/lib/apt/lists/*
