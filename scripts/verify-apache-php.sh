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

expected_message_json="$(php -r 'echo json_encode($argv[1]);' "${EXPECTED_MESSAGE}")"

cat > "${TEST_FILE_PATH}" <<PHP
<?php

header('Content-Type: application/json');

echo json_encode([
    'message' => ${expected_message_json},
    'sapi' => PHP_SAPI,

    'memory_limit' => ini_get('memory_limit'),
    'env_php_memory_limit' => getenv('PHP_MEMORY_LIMIT') ?: '',

    'opcache_memory_consumption' => ini_get('opcache.memory_consumption'),
    'env_php_opcache_memory_consumption' => getenv('PHP_OPCACHE_MEMORY_CONSUMPTION') ?: '',

    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'post_max_size' => ini_get('post_max_size'),
    'max_execution_time' => ini_get('max_execution_time'),

    'timezone' => ini_get('date.timezone'),
], JSON_PRETTY_PRINT);
PHP

cleanup() {
    if [ "${CLEANUP_TEST_FILE}" = "1" ]; then
        rm -f "${TEST_FILE_PATH}" || true
    fi
}
trap cleanup EXIT

response="$(curl -fsS "${URL}" | tr -d '\r')"

echo "Response:"
echo "${response}"

php_json_get() {
    local key="$1"

    printf '%s' "${response}" | php -r '
        $key = $argv[1];
        $data = json_decode(stream_get_contents(STDIN), true);

        if (!is_array($data)) {
            fwrite(STDERR, "ERROR: Invalid JSON response\n");
            exit(1);
        }

        echo $data[$key] ?? "";
    ' "${key}"
}

message="$(php_json_get message)"
sapi="$(php_json_get sapi)"

memory_limit="$(php_json_get memory_limit)"
env_php_memory_limit="$(php_json_get env_php_memory_limit)"

opcache_memory="$(php_json_get opcache_memory_consumption)"
env_php_opcache_memory="$(php_json_get env_php_opcache_memory_consumption)"

upload_max_filesize="$(php_json_get upload_max_filesize)"
post_max_size="$(php_json_get post_max_size)"
max_execution_time="$(php_json_get max_execution_time)"
timezone="$(php_json_get timezone)"

if [ "${message}" != "${EXPECTED_MESSAGE}" ]; then
    echo "ERROR: Apache/PHP response message mismatch." >&2
    echo "Expected: ${EXPECTED_MESSAGE}" >&2
    echo "Actual:   ${message}" >&2
    exit 1
fi

if [ -z "${sapi}" ]; then
    echo "ERROR: PHP SAPI was not returned." >&2
    exit 1
fi

if [ "${upload_max_filesize}" != "${PHP_UPLOAD_MAX_FILESIZE}" ]; then
    echo "ERROR: upload_max_filesize mismatch." >&2
    echo "Expected: ${PHP_UPLOAD_MAX_FILESIZE}" >&2
    echo "Actual:   ${upload_max_filesize}" >&2
    exit 1
fi

if [ "${post_max_size}" != "${PHP_POST_MAX_SIZE}" ]; then
    echo "ERROR: post_max_size mismatch." >&2
    echo "Expected: ${PHP_POST_MAX_SIZE}" >&2
    echo "Actual:   ${post_max_size}" >&2
    exit 1
fi

if [ "${max_execution_time}" != "${PHP_MAX_EXECUTION_TIME}" ]; then
    echo "ERROR: max_execution_time mismatch." >&2
    echo "Expected: ${PHP_MAX_EXECUTION_TIME}" >&2
    echo "Actual:   ${max_execution_time}" >&2
    exit 1
fi

echo
echo "Apache and PHP verification passed."
echo "PHP SAPI: ${sapi}"

echo
echo "Memory values:"
echo "ENV PHP_MEMORY_LIMIT: ${env_php_memory_limit}"
echo "PHP ini memory_limit: ${memory_limit}"
echo "ENV PHP_OPCACHE_MEMORY_CONSUMPTION: ${env_php_opcache_memory}"
echo "PHP ini opcache.memory_consumption: ${opcache_memory}M"

echo
echo "Runtime override values:"
echo "PHP upload_max_filesize: ${upload_max_filesize}"
echo "PHP post_max_size: ${post_max_size}"
echo "PHP max_execution_time: ${max_execution_time}"
echo "PHP timezone: ${timezone}"
