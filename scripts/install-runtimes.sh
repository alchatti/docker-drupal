#!/usr/bin/env bash
set -Eeuxo pipefail

echo "[runtime-db-init] Installing database clients and Redis PHP extension..."

PHP_PECL_EXTENSIONS="${PHP_PECL_EXTENSIONS:-redis}"

savedAptMark="$(apt-mark showmanual)"

apt-get update

apt-get install -y --no-install-recommends \
    ${PHPIZE_DEPS} \
    mariadb-client \
    postgresql-client

pecl channel-update pecl.php.net

for extension in ${PHP_PECL_EXTENSIONS}; do
    pecl install "${extension}"
    docker-php-ext-enable "${extension}"
done

# Mark all packages as automatic first.
apt-mark auto '.*' > /dev/null

# Restore packages that were manually installed before this script ran.
if [ -n "${savedAptMark}" ]; then
    apt-mark manual ${savedAptMark}
fi

# Keep the intended runtime database clients.
apt-mark manual \
    mariadb-client \
    postgresql-client

# Keep runtime shared-library dependencies required by installed PHP extensions.
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

rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /tmp/pear \
    /tmp/pear ~/.pearrc
