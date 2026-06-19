#!/usr/bin/env bash
set -euo pipefail

# Optional builder-only tools. Do not run this in the final production runtime
# unless you intentionally want Node.js and Composer available there.

set -x

NODE="${NODE:-22}"
INSTALL_COMPOSER="${INSTALL_COMPOSER:-1}"

apt-get update
apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    unzip

if [ "${INSTALL_COMPOSER}" = "1" ] && ! command -v composer >/dev/null 2>&1; then
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer-setup.php
fi

curl -fsSL "https://deb.nodesource.com/setup_${NODE}.x" | bash -
apt-get install -y --no-install-recommends nodejs

composer --version || true
node --version
npm --version

rm -rf /var/lib/apt/lists/*
