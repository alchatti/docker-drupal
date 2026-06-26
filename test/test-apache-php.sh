#!/usr/bin/env bash
# test/test-apache-php.sh
#
# External image test for apache (mod_php) and apache-fpm images.
#
# Preparation: writes a PHP probe file into a temp directory and mounts it
# as the Drupal web root before launching the container, so no docker exec
# or in-container verification script is needed.
#
# All checks are performed from the host using curl and jq.
#
# Usage:
#   ./test/test-apache-php.sh <IMAGE>
#   IMAGE=my/image:tag ./test/test-apache-php.sh
#
# Configuration (env-overridable):
#   DRUPAL_SUBDIR              URL sub-path, default: test-site
#   PHP_UPLOAD_MAX_FILESIZE    Expected value, also passed to container, default: 128M
#   PHP_POST_MAX_SIZE          Expected value, also passed to container, default: 129M
#   PHP_MAX_EXECUTION_TIME     Expected value, also passed to container, default: 180
#   TZ_EXPECTED                Expected PHP timezone, default: Asia/Dubai
#   EXPECTED_PHP_SAPI          When set, validates PHP_SAPI (e.g. apache2handler, fpm-fcgi)
#   HOST_PORT                  Port to publish on the host, default: 8080
#   RETRIES                    Number of readiness poll attempts, default: 30
#   RETRY_DELAY                Seconds between retries, default: 2

set -euo pipefail

IMAGE="${1:-${IMAGE:?Usage: $0 <image>  or  IMAGE=<image> $0}}"

DRUPAL_SUBDIR="${DRUPAL_SUBDIR:-test-site}"
PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-128M}"
PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-129M}"
PHP_MAX_EXECUTION_TIME="${PHP_MAX_EXECUTION_TIME:-180}"
TZ_EXPECTED="${TZ_EXPECTED:-Asia/Dubai}"
EXPECTED_PHP_SAPI="${EXPECTED_PHP_SAPI:-}"
HOST_PORT="${HOST_PORT:-8080}"
APACHE_PORT="${APACHE_PORT:-8080}"
RETRIES="${RETRIES:-30}"
RETRY_DELAY="${RETRY_DELAY:-2}"
EXPECTED_MESSAGE="${EXPECTED_MESSAGE:-Hello, Drupal Developer!}"

NAME="apache-php-test-${IMAGE//[^a-zA-Z0-9_.-]/-}"
WORKDIR="$(mktemp -d)"

# ── Cleanup ────────────────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "--- Container logs ---"
    docker logs "${NAME}" 2>/dev/null || true
    echo "--- End logs ---"
    docker rm -f "${NAME}" 2>/dev/null || true
    rm -rf "${WORKDIR}"
}
trap cleanup EXIT

# ── Step 1: Prepare PHP probe file (before container launch) ──────────────────
echo "Preparing test workspace: ${WORKDIR}"
chmod 755 "${WORKDIR}"

cat > "${WORKDIR}/__apache_php_verify.php" <<'PHP'
<?php
header('Content-Type: application/json');
echo json_encode([
    'message'             => 'Hello, Drupal Developer!',
    'sapi'                => PHP_SAPI,
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'post_max_size'       => ini_get('post_max_size'),
    'max_execution_time'  => (string) ini_get('max_execution_time'),
    'timezone'            => ini_get('date.timezone'),
], JSON_PRETTY_PRINT);
PHP

echo "Probe file written to: ${WORKDIR}/__apache_php_verify.php"

# ── Step 2: Launch container with probe directory mounted as web root ──────────
echo ""
echo "Launching container: ${NAME}"
docker rm -f "${NAME}" >/dev/null 2>&1 || true

docker run -d \
    --name "${NAME}" \
    -e "DRUPAL_SUBDIR=${DRUPAL_SUBDIR}" \
    -e "PHP_UPLOAD_MAX_FILESIZE=${PHP_UPLOAD_MAX_FILESIZE}" \
    -e "PHP_POST_MAX_SIZE=${PHP_POST_MAX_SIZE}" \
    -e "PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME}" \
    -e "APP_MISSING_PLACEHOLDER=0" \
    -v "${WORKDIR}:/app/web" \
    -p "${HOST_PORT}:${APACHE_PORT}" \
    "${IMAGE}"

# ── Step 3: Poll until probe URL responds ─────────────────────────────────────
if [ -n "${DRUPAL_SUBDIR}" ]; then
    PROBE_URL="http://127.0.0.1:${HOST_PORT}/${DRUPAL_SUBDIR}/__apache_php_verify.php"
else
    PROBE_URL="http://127.0.0.1:${HOST_PORT}/__apache_php_verify.php"
fi

echo ""
echo "Waiting for: ${PROBE_URL}"

RESPONSE=""
for i in $(seq 1 "${RETRIES}"); do
    if RESPONSE="$(curl -fsS --max-time 4 "${PROBE_URL}" 2>/dev/null)"; then
        echo "Container is ready (attempt ${i}/${RETRIES})."
        break
    fi

    if [ "${i}" -eq "${RETRIES}" ]; then
        echo "ERROR: Container did not respond after ${RETRIES} attempts." >&2
        exit 1
    fi

    echo "Not ready yet. Attempt ${i}/${RETRIES}, retrying in ${RETRY_DELAY}s..."
    sleep "${RETRY_DELAY}"
done

echo ""
echo "Response:"
echo "${RESPONSE}"

# ── Step 4: Verify response fields from outside the container ─────────────────
PASS=0
FAIL=0

check() {
    local label="$1"
    local expected="$2"
    local actual
    actual="$(printf '%s' "${RESPONSE}" | jq -r --arg k "${label}" '.[$k] // empty' 2>/dev/null)"

    if [ "${actual}" = "${expected}" ]; then
        echo "PASS: ${label} = ${actual}"
        PASS=$(( PASS + 1 ))
    else
        echo "FAIL: ${label}" >&2
        echo "  Expected: ${expected}" >&2
        echo "  Actual:   ${actual}" >&2
        FAIL=$(( FAIL + 1 ))
    fi
}

echo ""
echo "Verifying response fields..."

check "message"             "${EXPECTED_MESSAGE}"
check "upload_max_filesize" "${PHP_UPLOAD_MAX_FILESIZE}"
check "post_max_size"       "${PHP_POST_MAX_SIZE}"
check "max_execution_time"  "${PHP_MAX_EXECUTION_TIME}"
check "timezone"            "${TZ_EXPECTED}"

if [ -n "${EXPECTED_PHP_SAPI}" ]; then
    check "sapi" "${EXPECTED_PHP_SAPI}"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed."

if [ "${FAIL}" -gt 0 ]; then
    echo "ERROR: Image verification failed for: ${IMAGE}" >&2
    exit 1
fi

echo "Image verification passed for: ${IMAGE}"
