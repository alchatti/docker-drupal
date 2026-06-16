#!/usr/bin/env bash
set -euo pipefail

# install-builder-tools.sh
#
# This script is intended to run AFTER install-drupal-php-extensions.sh
#
# Required environment variable:
#   NODE=22
#   NODE=24
#   etc.

set -x

if [ -z "${NODE:-}" ]; then
    echo "ERROR: NODE version is not set."
    echo "Example: NODE=22 ./install-builder-tools.sh"
    exit 1
fi

apt-get update

apt-get install -y --no-install-recommends \
    unzip \
    ca-certificates \
    bash \
    curl

curl -fsSL "https://deb.nodesource.com/setup_${NODE}.x" | bash -

apt-get install -y --no-install-recommends \
    nodejs

echo "Composer version: $(composer --version)"
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

rm -rf /var/lib/apt/lists/*
