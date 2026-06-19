#!/usr/bin/env bash
set -Eeuo pipefail

# Easy to update later
DRUPAL_VERSION="${DRUPAL_VERSION:-^11}"

echo "Checking Composer, Node.js, npm, and Drupal project creation..."
echo "Drupal version constraint: ${DRUPAL_VERSION}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

export COMPOSER_ALLOW_SUPERUSER=1
export COMPOSER_HOME="${WORKDIR}/composer-home"
export npm_config_cache="${WORKDIR}/npm-cache"

echo
echo "Composer:"
command -v composer
composer --version

echo
echo "Node.js:"
command -v node
node --version
node -e 'console.log("Node runtime OK:", process.version)'

echo
echo "npm:"
command -v npm
npm --version
npm config get registry

echo
echo "Testing npm package install and execution..."
mkdir -p "${WORKDIR}/npm-test"
cd "${WORKDIR}/npm-test"

npm init -y >/dev/null
npm install is-number --no-audit --no-fund >/dev/null

node - <<'EOF'
const isNumber = require("is-number");
if (!isNumber(123)) {
  throw new Error("npm package test failed");
}
console.log("npm install/use OK");
EOF

echo
echo "Testing Drupal Composer project creation..."
cd "${WORKDIR}"

composer create-project \
  "drupal/recommended-project:${DRUPAL_VERSION}" \
  drupal-test \
  --no-interaction \
  --no-progress

cd "${WORKDIR}/drupal-test"

test -f composer.json
test -f web/index.php
test -d web/core
test -d vendor

php -r 'require "vendor/autoload.php"; echo "Composer autoload OK\n";'

echo
echo "Drupal project creation OK."
echo "Builder tools verification passed."
