#!/usr/bin/env bash
set -Eeuxo pipefail

# Reusable PHP runtime extension installer for official php:* Debian-based images.
# Installs: gd, opcache, pdo_mysql, pdo_pgsql, zip

PHP_BUILD_JOBS="${PHP_BUILD_JOBS:-$(nproc)}"

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
    --with-jpeg \
    --with-webp

docker-php-ext-install -j "${PHP_BUILD_JOBS}" \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip

# Mark all packages as automatic first.
apt-mark auto '.*' > /dev/null

# Restore packages that were manually installed before this script ran.
if [ -n "${savedAptMark}" ]; then
    apt-mark manual ${savedAptMark}
fi

# Keep only runtime shared-library dependencies required by installed PHP extensions.
find "$(php -r 'echo ini_get("extension_dir");')" -name '*.so' -print0 \
    | xargs -0 -r ldd \
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
    | xargs -r apt-mark manual

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
