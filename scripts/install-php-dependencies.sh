#!/usr/bin/env bash
set -euxo pipefail

# 1. Save original manual package markers
savedAptMark="$(apt-mark showmanual)"

# 2. Install shared system headers needed for standard PHP extensions
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

# 4. Compile core extensions using parallel hardware allocation properties
docker-php-ext-install -j "$(nproc)" \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip

# 5. Garbage Collection Clean-up
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
