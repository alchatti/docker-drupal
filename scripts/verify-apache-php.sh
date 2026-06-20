#!/usr/bin/env bash
set -euo pipefail

APACHE_PORT="${APACHE_PORT:-8080}"
DOC_ROOT="${DOC_ROOT:-/var/www/html/web}"
DRUPAL_SUBDIR="${DRUPAL_SUBDIR:-}"
TEST_FILE="${TEST_FILE:-__apache_php_verify.php}"
EXPECTED_MESSAGE="${EXPECTED_MESSAGE:-Hello, Drupal Developer!}"
CLEANUP_TEST_FILE="${CLEANUP_TEST_FILE:-1}"

TEST_PATH="/${TEST_FILE}"
TEST_FILE_PATH="${DOC_ROOT}/${TEST_FILE}"
CLEAN_SUBDIR="$(printf '%s' "${DRUPAL_SUBDIR}" | sed 's|^/||;s|/$||')"
if [ -n "${CLEAN_SUBDIR}" ]; then
    URL="http://127.0.0.1:${APACHE_PORT}/${CLEAN_SUBDIR}${TEST_PATH}"
else
    URL="http://127.0.0.1:${APACHE_PORT}${TEST_PATH}"
fi

echo "Verifying Apache and PHP..."
echo "Document root: ${DOC_ROOT}"
echo "Test file: ${TEST_FILE_PATH}"
echo "URL: ${URL}"
echo "Expected response: ${EXPECTED_MESSAGE}"

if [ ! -d "${DOC_ROOT}" ]; then
    echo "ERROR: Document root does not exist: ${DOC_ROOT}" >&2
    exit 1
fi

cat > "${TEST_FILE_PATH}" <<PHP
<?php
echo '${EXPECTED_MESSAGE}';
PHP

cleanup() {
    if [ "${CLEANUP_TEST_FILE}" = "1" ]; then
        rm -f "${TEST_FILE_PATH}" || true
    fi
}
trap cleanup EXIT

response="$(curl -fsS "${URL}" | tr -d '\r')"

echo "Actual response: ${response}"

if [ "${response}" != "${EXPECTED_MESSAGE}" ]; then
    echo "ERROR: Apache/PHP verification failed." >&2
    echo "Expected: ${EXPECTED_MESSAGE}" >&2
    echo "Actual:   ${response}" >&2
    exit 1
fi

echo "Apache and PHP verification passed."
