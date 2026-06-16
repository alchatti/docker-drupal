#!/usr/bin/env bash
set -euxo pipefail

# Accept Node version from argument, default to 20 if not provided
NODE_VERSION="${1:-20}"

echo "[builder-init] Installing build-essential system binaries..."

# 1. Install baseline tools needed specifically for building/compiling assets
apt-get update
apt-get install -y --no-install-recommends \
    unzip \
    ca-certificates \
    curl \
    gnupg

# 2. Modern Nodesource installation syntax (Secure GPG key extraction)
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
    | tee /etc/apt/sources.list.d/nodesource.list

apt-get update
apt-get install -y --no-install-recommends nodejs

# 3. Aggressive image size cleanup for the builder layer
apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false gnupg
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
