#!/usr/bin/env bash
# Shared Drupal layout helpers.
# Sourced by docker-entrypoint-apache.sh.
# Not intended to be executed directly.
#
# Opinionated layout:
#   APP_ROOT=/app
#   DOC_ROOT=/app/web
#   PUBLIC_ROOT=/var/www/html
#
# Public files symlink policy:
#   The application image must contain:
#     /app/web/files -> /mnt/files/public
#
# The runtime entrypoint does not migrate or create application public files.
# Volume initialization, seeding, backup, and restore are handled by the
# vmaker image.

clean_path_segment() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR: clean_path_segment expects exactly one argument." >&2
        exit 1
    fi

    # Empty is valid for optional values such as DRUPAL_SUBDIR.
    printf '%s' "$1" | sed 's|^/||;s|/$||'
}

require_absolute_path() {
    if [ "$#" -ne 2 ]; then
        echo "ERROR: require_absolute_path expects variable name and value." >&2
        exit 1
    fi

    local name="$1"
    local value="$2"

    if [ -z "${value}" ]; then
        echo "ERROR: ${name} must not be empty." >&2
        exit 1
    fi

    case "${value}" in
        /*) ;;
        *)
            echo "ERROR: ${name} must be an absolute path. Current value: ${value}" >&2
            exit 1
            ;;
    esac
}

safe_rm_rf() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR: safe_rm_rf expects exactly one path argument." >&2
        exit 1
    fi

    local target="$1"

    case "${target}" in
        ""|"/"|"/app"|"/app/"|"/var"|"/var/"|"/var/www"|"/var/www/")
            echo "ERROR: Refusing to remove unsafe path: ${target}" >&2
            exit 1
            ;;
    esac

    if [ -n "${APP_ROOT:-}" ]; then
        case "${target}" in
            "${APP_ROOT}"|"${APP_ROOT}/")
                echo "ERROR: Refusing to remove APP_ROOT: ${target}" >&2
                exit 1
                ;;
        esac
    fi

    if [ -n "${DOC_ROOT:-}" ]; then
        case "${target}" in
            "${DOC_ROOT}"|"${DOC_ROOT}/")
                echo "ERROR: Refusing to remove DOC_ROOT: ${target}" >&2
                exit 1
                ;;
        esac
    fi

    rm -rf "${target}"
}

resolve_doc_root() {
    : "${APP_ROOT:=/app}"
    : "${PUBLIC_ROOT:=/var/www/html}"

    require_absolute_path "APP_ROOT" "${APP_ROOT}"
    require_absolute_path "PUBLIC_ROOT" "${PUBLIC_ROOT}"

    DOC_ROOT="${APP_ROOT}/web"

    require_absolute_path "DOC_ROOT" "${DOC_ROOT}"

    export DOC_ROOT
}

validate_app_files_symlink() {
    : "${FILES_DIR:=/mnt/files}"
    : "${DRUPAL_PUBLIC_FILES_PATH:=files}"
    : "${DRUPAL_PUBLIC_FILES_SOURCE:=${FILES_DIR}/public}"

    local public_files_path
    local public_files_mount
    local current_target

    require_absolute_path "DOC_ROOT" "${DOC_ROOT:-}"
    require_absolute_path "DRUPAL_PUBLIC_FILES_SOURCE" "${DRUPAL_PUBLIC_FILES_SOURCE}"

    public_files_path="$(clean_path_segment "${DRUPAL_PUBLIC_FILES_PATH}")"

    if [ -z "${public_files_path}" ]; then
        echo "ERROR: DRUPAL_PUBLIC_FILES_PATH cannot be empty." >&2
        exit 1
    fi

    case "${public_files_path}" in
        *".."*|/*)
            echo "ERROR: Invalid DRUPAL_PUBLIC_FILES_PATH=${DRUPAL_PUBLIC_FILES_PATH}" >&2
            echo "Use a web-relative path such as: files" >&2
            exit 1
            ;;
    esac

    public_files_mount="${DOC_ROOT}/${public_files_path}"

    if [ ! -L "${public_files_mount}" ]; then
        echo "ERROR: Public files path must be a symlink created at app build time." >&2
        echo "Expected: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}" >&2
        exit 1
    fi

    current_target="$(readlink "${public_files_mount}")"

    if [ "${current_target}" != "${DRUPAL_PUBLIC_FILES_SOURCE}" ]; then
        echo "ERROR: Public files symlink points to the wrong target." >&2
        echo "Expected: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}" >&2
        echo "Actual:   ${public_files_mount} -> ${current_target}" >&2
        exit 1
    fi

    echo "[system-init] Public files symlink verified: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}"
}
