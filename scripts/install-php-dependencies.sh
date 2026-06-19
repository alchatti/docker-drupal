#!/usr/bin/env bash
set -euo pipefail

# Build-time Drupal PHP extensions for official Debian-based PHP images.
# Installs common Drupal runtime extensions and removes build deps afterwards.

set -x

if ! command -v docker-php-ext-install >/dev/null 2>&1; then
    echo "ERROR: docker-php-ext-install was not found. Use an official PHP Docker base image." >&2
    exit 1
fi

savedAptMark="$(apt-mark showmanual)"

apt-get update
apt-get install -y --no-install-recommends \
    unzip \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev

docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

docker-php-ext-install -j "$(nproc)" \
    gd \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip

# Reset apt-mark so build dependencies can be removed while keeping runtime libs.
apt-mark auto '.*' >/dev/null
# shellcheck disable=SC2086
apt-mark manual ${savedAptMark}

extensionDir="$(php -r 'echo ini_get("extension_dir");')"
if find "${extensionDir}" -name '*.so' -type f | grep -q .; then
    find "${extensionDir}" -name '*.so' -type f -print0 \
        | xargs -0 ldd \
        | awk '/=>/ {
            so = $(NF-1)
            if (index(so, "/usr/local/") == 1) next
            gsub("^/(usr/)?", "", so)
            printf "*%s\n", so
        }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -r apt-mark manual
fi

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/*
