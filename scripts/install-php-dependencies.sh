#!/usr/bin/env bash
set -euxo pipefail

# 1. Save original manual package markers
savedAptMark="$(apt-mark showmanual)"

# 2. Install shared system headers
apt-get update
apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev \
    libxml2-dev

# 3. Configure core image optimization layers
docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg=/usr \
    --with-webp

# 4. Compile robust core extensions using parallel hardware allocation
docker-php-ext-install -j "$(nproc)" \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql

# 5. Compile the Zip extension SEQUENTIALLY (Fixes the 'install-modules' race condition)
docker-php-ext-install zip

# 6. Garbage Collection Clean-up
apt-mark auto '.*' > /dev/null
apt-mark manual $savedAptMark

ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
