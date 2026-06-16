#!/usr/bin/env bash
set -euo pipefail

set -x

INSTALL_MARIADB=false
INSTALL_POSTGRESQL=false
INSTALL_REDIS=false
INSTALL_MEMCACHED=false
INSTALL_IMAGICK=false

usage() {
    cat <<'EOF'
Usage:
  install-runtimes.sh [options]

Database clients:
  --mariadb       Install MariaDB client
  --postgresql    Install PostgreSQL client

PHP PECL extensions:
  --redis         Install PHP Redis extension
  --memcached     Install PHP Memcached extension
  --memcache      Alias for --memcached
  --imagick       Install PHP Imagick extension

Groups:
  --db            Install MariaDB and PostgreSQL clients
  --pecl          Install redis, memcached, and imagick
  --all           Install everything

Help:
  -h, --help      Show this help message

Examples:
  install-runtimes.sh --mariadb --postgresql
  install-runtimes.sh --redis --imagick
  install-runtimes.sh --db --redis
  install-runtimes.sh --all
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mariadb|--mysql)
            INSTALL_MARIADB=true
            ;;
        --postgresql|--postgres|--pgsql)
            INSTALL_POSTGRESQL=true
            ;;
        --redis)
            INSTALL_REDIS=true
            ;;
        --memcached|--memcache)
            INSTALL_MEMCACHED=true
            ;;
        --imagick)
            INSTALL_IMAGICK=true
            ;;
        --db)
            INSTALL_MARIADB=true
            INSTALL_POSTGRESQL=true
            ;;
        --pecl)
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=true
            INSTALL_IMAGICK=true
            ;;
        --all)
            INSTALL_MARIADB=true
            INSTALL_POSTGRESQL=true
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=true
            INSTALL_IMAGICK=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "${INSTALL_MARIADB}" = false ] \
    && [ "${INSTALL_POSTGRESQL}" = false ] \
    && [ "${INSTALL_REDIS}" = false ] \
    && [ "${INSTALL_MEMCACHED}" = false ] \
    && [ "${INSTALL_IMAGICK}" = false ]; then
    echo "ERROR: No runtime option selected."
    usage
    exit 1
fi

NEEDS_PECL=false

if [ "${INSTALL_REDIS}" = true ] \
    || [ "${INSTALL_MEMCACHED}" = true ] \
    || [ "${INSTALL_IMAGICK}" = true ]; then
    NEEDS_PECL=true
fi

if [ "${NEEDS_PECL}" = true ]; then
    if ! command -v docker-php-ext-enable >/dev/null 2>&1; then
        echo "ERROR: docker-php-ext-enable was not found."
        echo "This script is intended for official PHP Docker images."
        exit 1
    fi

    if ! command -v pecl >/dev/null 2>&1; then
        echo "ERROR: pecl was not found."
        echo "This script is intended for official PHP Docker images with PEAR/PECL available."
        exit 1
    fi
fi

savedAptMark="$(apt-mark showmanual)"

apt-get update

runtimeDeps=""

if [ "${INSTALL_MARIADB}" = true ]; then
    runtimeDeps="${runtimeDeps} mariadb-client"
fi

if [ "${INSTALL_POSTGRESQL}" = true ]; then
    runtimeDeps="${runtimeDeps} postgresql-client"
fi

if [ -n "${runtimeDeps}" ]; then
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends ${runtimeDeps}
fi

buildDeps=""

if [ "${INSTALL_REDIS}" = true ]; then
    buildDeps="${buildDeps} autoconf g++ make pkg-config"
fi

if [ "${INSTALL_MEMCACHED}" = true ]; then
    buildDeps="${buildDeps} autoconf g++ make pkg-config libmemcached-dev zlib1g-dev"
fi

if [ "${INSTALL_IMAGICK}" = true ]; then
    buildDeps="${buildDeps} autoconf g++ make pkg-config libmagickwand-dev"
fi

if [ -n "${buildDeps}" ]; then
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends ${buildDeps}
fi

if [ "${INSTALL_REDIS}" = true ]; then
    pecl install redis
    docker-php-ext-enable redis
fi

if [ "${INSTALL_MEMCACHED}" = true ]; then
    pecl install memcached
    docker-php-ext-enable memcached
fi

if [ "${INSTALL_IMAGICK}" = true ]; then
    pecl install imagick
    docker-php-ext-enable imagick
fi

# Reset apt-mark so build dependencies can be removed,
# while keeping required runtime libraries.
apt-mark auto '.*' >/dev/null

# shellcheck disable=SC2086
apt-mark manual ${savedAptMark}

if [ -n "${runtimeDeps}" ]; then
    # shellcheck disable=SC2086
    apt-mark manual ${runtimeDeps}
fi

if [ "${NEEDS_PECL}" = true ]; then
    extensionDir="$(php -r 'echo ini_get("extension_dir");')"

    if find "${extensionDir}" -name '*.so' -type f | grep -q .; then
        find "${extensionDir}" -name '*.so' -type f -print0 \
            | xargs -0 ldd \
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
    fi
fi

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

rm -rf /tmp/pear ~/.pearrc /var/lib/apt/lists/*
