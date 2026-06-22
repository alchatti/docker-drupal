#!/usr/bin/env bash
# Shared Drupal layout helpers.
# Sourced by docker-entrypoint-apache.sh and verify-apache-php.sh.
# Not intended to be executed directly.

clean_path_segment() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR: clean_path_segment expects exactly one argument." >&2
        exit 1
    fi

    if [ -z "$1" ]; then
        echo "ERROR: clean_path_segment argument must not be empty." >&2
        exit 1
    fi

    printf '%s' "$1" | sed 's|^/||;s|/$||'
}

safe_rm_rf() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR: safe_rm_rf expects exactly one path argument." >&2
        exit 1
    fi

    local target="$1"

    case "${target}" in
        ""|"/"|"/app"|"/app/"|"/var"|"/var/"|"/var/www"|"/var/www/"|"${APP_ROOT}"|"${APP_ROOT}/"|"${DOC_ROOT}"|"${DOC_ROOT}/")
            echo "ERROR: Refusing to remove unsafe path: ${target}" >&2
            exit 1
            ;;
    esac

    rm -rf "${target}"
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

    if [ -z "${APP_ROOT}" ]; then
        echo "ERROR: APP_ROOT must not be empty." >&2
        exit 1
    fi

    if [[ "${APP_ROOT}" != /* ]]; then
        echo "ERROR: APP_ROOT must be an absolute path. Current value: ${APP_ROOT}" >&2
        exit 1
    fi

    if [ -z "${DOC_ROOT}" ]; then
        DOC_ROOT="${APP_ROOT}/${public_dir}"
    fi

    if [[ "${DOC_ROOT}" != /* ]]; then
        echo "ERROR: DOC_ROOT must be an absolute path. Current value: ${DOC_ROOT}" >&2
        exit 1
    fi

    if [ -z "${PUBLIC_ROOT}" ]; then
        echo "ERROR: PUBLIC_ROOT must not be empty." >&2
        exit 1
    fi

    if [[ "${PUBLIC_ROOT}" != /* ]]; then
        echo "ERROR: PUBLIC_ROOT must be an absolute path. Current value: ${PUBLIC_ROOT}" >&2
        exit 1
    fi

    export DOC_ROOT
}
