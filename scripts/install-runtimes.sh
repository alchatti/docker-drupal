#!/usr/bin/env bash
set -euo pipefail

# Optional runtime packages and PHP extensions.
# Simple mode: installed packages remain installed.
# Intended for official Debian-based PHP Docker images.

set -x

INSTALL_MARIADB=false
INSTALL_POSTGRESQL=false
INSTALL_SQLITE=false
INSTALL_REDIS=false
INSTALL_MEMCACHED=false
INSTALL_IMAGICK=false

usage() {
    cat <<'USAGE'
Usage:
  install-runtimes.sh [options]

Database clients / extensions:
  --mariadb       Install MariaDB client
  --postgresql    Install PostgreSQL client
  --sqlite        Install SQLite CLI and PHP sqlite3/pdo_sqlite extensions

PHP PECL extensions:
  --redis         Install PHP Redis extension
  --memcached     Install PHP Memcached extension
  --memcache      Alias for --memcached
  --imagick       Install PHP Imagick extension

Groups:
  --db            Install MariaDB, PostgreSQL, and SQLite support
  --pecl          Install redis, memcached, and imagick
  --all           Install everything

Help:
  -h, --help      Show this help message
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --mariadb|--mysql)
            INSTALL_MARIADB=true
            ;;
        --postgresql|--postgres|--pgsql)
            INSTALL_POSTGRESQL=true
            ;;
        --sqlite|--sqlite3)
            INSTALL_SQLITE=true
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
            INSTALL_SQLITE=true
            ;;
        --pecl)
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=true
            INSTALL_IMAGICK=true
            ;;
        --all)
            INSTALL_MARIADB=true
            INSTALL_POSTGRESQL=true
            INSTALL_SQLITE=true
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=true
            INSTALL_IMAGICK=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac

    shift
done

if [ "${INSTALL_MARIADB}" = false ] \
    && [ "${INSTALL_POSTGRESQL}" = false ] \
    && [ "${INSTALL_SQLITE}" = false ] \
    && [ "${INSTALL_REDIS}" = false ] \
    && [ "${INSTALL_MEMCACHED}" = false ] \
    && [ "${INSTALL_IMAGICK}" = false ]; then
    echo "ERROR: No runtime option selected." >&2
    usage >&2
    exit 1
fi

NEEDS_PECL=false
PECL_BUILD_DEPS=""

if [ "${INSTALL_REDIS}" = true ] \
    || [ "${INSTALL_MEMCACHED}" = true ] \
    || [ "${INSTALL_IMAGICK}" = true ]; then
    NEEDS_PECL=true
fi

apt-get update

packages=""

if [ "${INSTALL_MARIADB}" = true ]; then
    packages="${packages} mariadb-client"
fi

if [ "${INSTALL_POSTGRESQL}" = true ]; then
    packages="${packages} postgresql-client"
fi

if [ "${INSTALL_SQLITE}" = true ]; then
    packages="${packages} sqlite3 libsqlite3-dev"
fi

if [ "${NEEDS_PECL}" = true ]; then
    packages="${packages} ${PHPIZE_DEPS:-autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c}"
    PECL_BUILD_DEPS="${PHPIZE_DEPS:-autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c}"
fi

if [ "${INSTALL_MEMCACHED}" = true ]; then
    packages="${packages} libmemcached-dev zlib1g-dev"
fi

if [ "${INSTALL_IMAGICK}" = true ]; then
    packages="${packages} libmagickwand-dev"
fi

if [ -n "${packages}" ]; then
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends ${packages}
fi

if [ "${INSTALL_SQLITE}" = true ]; then
    docker-php-ext-install -j "$(nproc)" \
        sqlite3 \
        pdo_sqlite
fi

if [ "${INSTALL_REDIS}" = true ]; then
    pecl install redis-6
    docker-php-ext-enable redis
fi

if [ "${INSTALL_MEMCACHED}" = true ]; then
    pecl install memcached-3
    docker-php-ext-enable memcached
fi

if [ "${INSTALL_IMAGICK}" = true ]; then
    pecl install imagick-3
    docker-php-ext-enable imagick
fi

if [ "${NEEDS_PECL}" = true ] && [ -n "${PECL_BUILD_DEPS}" ]; then
    # shellcheck disable=SC2086
    apt-get purge -y --auto-remove ${PECL_BUILD_DEPS}
fi

rm -rf /tmp/pear ~/.pearrc /var/lib/apt/lists/*
