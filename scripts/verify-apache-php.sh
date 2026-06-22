#!/usr/bin/env bash
set -euo pipefail

APACHE_PORT="${APACHE_PORT:-8080}"

APP_ROOT="${APP_ROOT:-/app}"
PUBLIC_ROOT="${PUBLIC_ROOT:-/var/www/html}"
DRUPAL_PUBLIC_DIR="${DRUPAL_PUBLIC_DIR:-web}"
DOC_ROOT="${DOC_ROOT:-}"

DRUPAL_SUBDIR="${DRUPAL_SUBDIR:-}"
TEST_FILE="${TEST_FILE:-__apache_php_verify.php}"
EXPECTED_MESSAGE="${EXPECTED_MESSAGE:-Hello, Drupal Developer!}"
CLEANUP_TEST_FILE="${CLEANUP_TEST_FILE:-1}"

PHP_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-64M}"
PHP_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-64M}"
PHP_MAX_EXECUTION_TIME="${PHP_MAX_EXECUTION_TIME:-120}"
TZ="${TZ:-Asia/Dubai}"

CURL_RETRIES="${CURL_RETRIES:-10}"
CURL_RETRY_DELAY="${CURL_RETRY_DELAY:-2}"

# Optional.
# Example:
#   EXPECTED_PHP_SAPI=apache2handler
#   EXPECTED_PHP_SAPI=fpm-fcgi
EXPECTED_PHP_SAPI="${EXPECTED_PHP_SAPI:-}"

clean_path_segment() {
    printf '%s' "$1" | sed 's|^/||;s|/$||'
}

resolve_doc_root() {
    local public_dir

    public_dir="$(clean_path_segment "${DRUPAL_PUBLIC_DIR:-web}")"

    case "${public_dir}" in
        web|docroot)
            ;;
        *)
            echo "ERROR: Invalid DRUPAL_PUBLIC_DIR=${DRUPAL_PUBLIC_DIR}" >&2
            echo "Allowed values: web, docroot" >&2
            exit 1
            ;;
    esac

    if [ -z "${DOC_ROOT}" ]; then
        DOC_ROOT="${APP_ROOT}/${public_dir}"
    fi

    if [[ "${DOC_ROOT}" != /* ]]; then
        echo "ERROR: DOC_ROOT must be an absolute path. Current value: ${DOC_ROOT}" >&2
        exit 1
    fi

    export DOC_ROOT
}

resolve_url() {
    local clean_subdir
    local test_path

    clean_subdir="$(clean_path_segment "${DRUPAL_SUBDIR}")"
    test_path="/${TEST_FILE}"

    if [ -n "${clean_subdir}" ]; then
        URL="http://127.0.0.1:${APACHE_PORT}/${clean_subdir}${test_path}"
        PUBLIC_TEST_PATH="${PUBLIC_ROOT}/${clean_subdir}/${TEST_FILE}"
    else
        URL="http://127.0.0.1:${APACHE_PORT}${test_path}"
        PUBLIC_TEST_PATH="${PUBLIC_ROOT}/${TEST_FILE}"
    fi

    CLEAN_SUBDIR="${clean_subdir}"
    export URL PUBLIC_TEST_PATH CLEAN_SUBDIR
}

resolve_doc_root
resolve_url

TEST_FILE_PATH="${DOC_ROOT}/${TEST_FILE}"

echo "Verifying Apache and PHP..."
echo "Runtime mode: ${DRUPAL_RUNTIME_MODE:-unknown}"
echo "App root: ${APP_ROOT}"
echo "Drupal public dir: ${DRUPAL_PUBLIC_DIR}"
echo "Resolved document root: ${DOC_ROOT}"
echo "Apache public root: ${PUBLIC_ROOT}"
echo "Drupal subdir: ${CLEAN_SUBDIR:-<root>}"
echo "Test file path: ${TEST_FILE_PATH}"
echo "Public test path: ${PUBLIC_TEST_PATH}"
echo "URL: ${URL}"
echo "Expected response: ${EXPECTED_MESSAGE}"

if [ ! -d "${DOC_ROOT}" ]; then
    echo "ERROR: Resolved document root does not exist: ${DOC_ROOT}" >&2
    echo "Check APP_ROOT, DRUPAL_PUBLIC_DIR, or DOC_ROOT." >&2
    exit 1
fi

if [ ! -d "${PUBLIC_ROOT}" ] && [ ! -L "${PUBLIC_ROOT}" ]; then
    echo "ERROR: Apache public root does not exist: ${PUBLIC_ROOT}" >&2
    echo "The entrypoint should create this as a symlink or directory." >&2
    exit 1
fi

if [ -n "${CLEAN_SUBDIR}" ] && [ ! -e "${PUBLIC_ROOT}/${CLEAN_SUBDIR}" ]; then
    echo "ERROR: Expected subdirectory mount does not exist: ${PUBLIC_ROOT}/${CLEAN_SUBDIR}" >&2
    echo "The entrypoint should create: ${PUBLIC_ROOT}/${CLEAN_SUBDIR} -> ${DOC_ROOT}" >&2
    exit 1
fi

if [ -z "${CLEAN_SUBDIR}" ] && [ ! -e "${PUBLIC_ROOT}" ]; then
    echo "ERROR: Expected root mount does not exist: ${PUBLIC_ROOT}" >&2
    echo "The entrypoint should create: ${PUBLIC_ROOT} -> ${DOC_ROOT}" >&2
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

    'document_root' => \$_SERVER['DOCUMENT_ROOT'] ?? '',
    'script_name' => \$_SERVER['SCRIPT_NAME'] ?? '',
    'request_uri' => \$_SERVER['REQUEST_URI'] ?? '',
], JSON_PRETTY_PRINT);
PHP

cleanup() {
    if [ "${CLEANUP_TEST_FILE}" = "1" ]; then
        rm -f "${TEST_FILE_PATH}" || true
    fi
}
trap cleanup EXIT

response=""

for attempt in $(seq 1 "${CURL_RETRIES}"); do
    if response="$(curl -fsS "${URL}" | tr -d '\r')"; then
        break
    fi

    if [ "${attempt}" -eq "${CURL_RETRIES}" ]; then
        echo "ERROR: Failed to reach Apache/PHP after ${CURL_RETRIES} attempts." >&2
        echo "URL: ${URL}" >&2
        exit 1
    fi

    echo "Apache/PHP not ready yet. Retry ${attempt}/${CURL_RETRIES}..."
    sleep "${CURL_RETRY_DELAY}"
done

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

document_root="$(php_json_get document_root)"
script_name="$(php_json_get script_name)"
request_uri="$(php_json_get request_uri)"

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

if [ -n "${EXPECTED_PHP_SAPI}" ] && [ "${sapi}" != "${EXPECTED_PHP_SAPI}" ]; then
    echo "ERROR: PHP SAPI mismatch." >&2
    echo "Expected: ${EXPECTED_PHP_SAPI}" >&2
    echo "Actual:   ${sapi}" >&2
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

if [ "${timezone}" != "${TZ}" ]; then
    echo "ERROR: timezone mismatch." >&2
    echo "Expected: ${TZ}" >&2
    echo "Actual:   ${timezone}" >&2
    exit 1
fi

echo
echo "Apache and PHP verification passed."
echo "PHP SAPI: ${sapi}"

echo
echo "Resolved layout:"
echo "APP_ROOT: ${APP_ROOT}"
echo "DRUPAL_PUBLIC_DIR: ${DRUPAL_PUBLIC_DIR}"
echo "DOC_ROOT: ${DOC_ROOT}"
echo "PUBLIC_ROOT: ${PUBLIC_ROOT}"
echo "DRUPAL_SUBDIR: ${CLEAN_SUBDIR:-<root>}"
echo "URL: ${URL}"

echo
echo "Request values:"
echo "DOCUMENT_ROOT from PHP: ${document_root}"
echo "SCRIPT_NAME from PHP: ${script_name}"
echo "REQUEST_URI from PHP: ${request_uri}"

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
