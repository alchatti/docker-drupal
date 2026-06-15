#!/usr/bin/env bash
set -eux

# 1. Save original manual package markers
savedAptMark="$(apt-mark showmanual)"

# 2. Synchronize repository tracking indices and install core binary headers
apt-get update
apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev \
    libxml2-dev \
    mariadb-client \
    postgresql-client

# 3. Configure core image optimization layers
docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

# 4. Compile core extensions using parallel hardware allocation properties
docker-php-ext-install -j "$(nproc)" \
    gd \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip

# 5. Connect and initialize PECL tracking records for Redis socket translation
pecl channel-update pecl.php.net
pecl install redis
docker-php-ext-enable redis

# 6. Production Post-Build Garbage Collection Clean-up
apt-mark auto '.*' > /dev/null
apt-mark manual $savedAptMark

# Isolate dynamically linked system library dependencies to prevent application runtime failures
ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual

# Purge leftover source packages and strip apt cache directories
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
