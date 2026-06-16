#!/usr/bin/env bash
set -euo pipefail

# install-runtime-tools.sh
#
# Installs runtime database clients and optional PHP extensions.
#
# Default:
#   install-runtime-tools
#
# Optional flags:
#   install-runtime-tools --redis
#   install-runtime-tools --memcached
#   install-runtime-tools --imagick
#   install-runtime-tools --redis --memcached --imagick
#
# Intended for Debian/Ubuntu-based official PHP images.

set -x

INSTALL_REDIS=false
INSTALL_MEMCACHED=false
INSTALL_IMAGICK=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --redis)
            INSTALL_REDIS=true
            ;;
        --memcached|--memcache)
            INSTALL_MEMCACHED=true
            ;;
        --imagick)
            INSTALL_IMAGICK=true
            ;;
        --all)
            INSTALL_REDIS=true
            INSTALL_MEMCACHED=true
            INSTALL_IMAGICK=true
            ;;
        -h|--help)
            cat <<'EOF'
Usage:
  install-runtime-tools [options]

Options:
  --redis        Install PHP Redis extension using PECL
  --memcached    Install PHP Memcached extension using PECL
  --memcache     Alias for --memcached
  --imagick      Install PHP Imagick extension using PECL
  --all          Install redis, memcached, and imagick
  -h, --help     Show this help message
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

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

savedAptMark="$(apt-mark showmanual)"

apt-get update

apt-get install -y --no-install-recommends \
    mariadb-client \
    postgresql-client

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

# Keep runtime libraries required by installed PHP extensions
if compgen -G "$(php -r 'echo ini_get("extension_dir");')"/*.so" > /dev/null; then
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
fi

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

rm -rf /tmp/pear ~/.pearrc /var/lib/apt/lists/* 
