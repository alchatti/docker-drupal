#!/usr/bin/env bash
set -Eeuxo pipefail

NODE_VERSION="${1:-20}"

echo "[builder-init] Installing builder tools..."

. /etc/os-release

apt-get update

apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip

# Debian 13 / trixie path: avoid NodeSource repository surprises.
if [ "${VERSION_CODENAME:-}" = "trixie" ]; then
    echo "[builder-init] Detected Debian trixie; installing Node.js from Debian repositories."

    apt-get install -y --no-install-recommends \
        nodejs \
        npm
else
    case "${NODE_VERSION}" in
        ''|*[!0-9]*)
            echo "[builder-init] ERROR: NODE_VERSION must be a numeric major version, e.g. 20 or 22." >&2
            exit 1
            ;;
    esac

    echo "[builder-init] Installing Node.js ${NODE_VERSION}.x from NodeSource..."

    apt-get install -y --no-install-recommends \
        gnupg

    install -d -m 0755 /usr/share/keyrings

    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg

    chmod a+r /usr/share/keyrings/nodesource.gpg

    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VERSION}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list

    apt-get update

    apt-get install -y --no-install-recommends \
        nodejs

    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false gnupg
fi

echo "[builder-init] Installed versions:"
node --version
npm --version
git --version
unzip -v | head -n 1

rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*
