#!/usr/bin/env bash
set -Eeuxo pipefail

# Builder image initializer for Debian-based official PHP images.
# Installs build tools and Node.js for CI/CD asset builds.

NODE_VERSION="${1:-20}"

case "${NODE_VERSION}" in
    ''|*[!0-9]*)
        echo "[builder-init] ERROR: NODE_VERSION must be a numeric major version, e.g. 20 or 22." >&2
        exit 1
        ;;
esac

echo "[builder-init] Installing builder tools with Node.js ${NODE_VERSION}.x..."

savedAptMark="$(apt-mark showmanual)"

apt-get update

apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    unzip

install -d -m 0755 /usr/share/keyrings

curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg

chmod a+r /usr/share/keyrings/nodesource.gpg

echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list

apt-get update

apt-get install -y --no-install-recommends \
    nodejs

echo "[builder-init] Installed versions:"
node --version
npm --version
git --version
unzip -v | head -n 1

# Keep the builder image predictable, but remove packages that are only needed
# during installation, such as gnupg.
apt-mark auto '.*' > /dev/null

if [ -n "${savedAptMark}" ]; then
    apt-mark manual ${savedAptMark}
fi

apt-mark manual \
    ca-certificates \
    curl \
    git \
    nodejs \
    unzip

apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*
