#!/usr/bin/env bash
set -euxo pipefail

echo "[runtime-db-init] Synchronizing database clients and Redis cache extensions..."

# 1. Save original manual package markers
savedAptMark="$(apt-mark showmanual)"

# 2. Install native database command-line clients
apt-get update
apt-get install -y --no-install-recommends \
    mariadb-client \
    postgresql-client

# 3. Compile and enable PECL Redis extension
pecl channel-update pecl.php.net
pecl install redis
docker-php-ext-enable redis

# 4. Post-Build Garbage Collection & Minimization
apt-mark auto '.*' > /dev/null
apt-mark manual $savedAptMark

# Isolate dynamically linked system libraries to keep the image footprint lean
ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u \
    | xargs -r dpkg-query -S \
    | cut -d: -f1 \
    | sort -u \
    | xargs -rt apt-mark manual

# Purge build-essential leftovers and strip apt cache directories
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /tmp/peer /tmp/packagexml
