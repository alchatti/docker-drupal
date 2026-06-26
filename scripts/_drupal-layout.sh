#!/usr/bin/env bash
# Shared Drupal layout helpers.
# Sourced by docker-entrypoint-apache.sh and verify-apache-php.sh.
# Not intended to be executed directly.

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

    if [ -n "${FILES_DIR:-}" ]; then
        case "${target}" in
            "${FILES_DIR}"|"${FILES_DIR}/")
                echo "ERROR: Refusing to remove FILES_DIR: ${target}" >&2
                exit 1
                ;;
        esac
    fi

    if [ -n "${DRUPAL_PUBLIC_FILES_SOURCE:-}" ]; then
        case "${target}" in
            "${DRUPAL_PUBLIC_FILES_SOURCE}"|"${DRUPAL_PUBLIC_FILES_SOURCE}/")
                echo "ERROR: Refusing to remove DRUPAL_PUBLIC_FILES_SOURCE: ${target}" >&2
                exit 1
                ;;
        esac
    fi

    rm -rf "${target}"
}

is_dir_empty() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR: is_dir_empty expects exactly one directory argument." >&2
        exit 1
    fi

    local dir="$1"

    [ -z "$(find "${dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]
}

move_dir_contents_safely() {
    if [ "$#" -ne 2 ]; then
        echo "ERROR: move_dir_contents_safely expects source and target directories." >&2
        exit 1
    fi

    local from_dir="$1"
    local to_dir="$2"
    local item
    local base
    local entries=()

    if [ ! -d "${from_dir}" ]; then
        echo "ERROR: Source directory does not exist: ${from_dir}" >&2
        exit 1
    fi

    mkdir -p "${to_dir}"

    shopt -s dotglob nullglob
    entries=("${from_dir}"/*)

    if [ "${#entries[@]}" -eq 0 ]; then
        shopt -u dotglob nullglob
        return
    fi

    for item in "${entries[@]}"; do
        base="$(basename "${item}")"

        if [ -e "${to_dir}/${base}" ] || [ -L "${to_dir}/${base}" ]; then
            echo "ERROR: Cannot migrate public files because target already exists: ${to_dir}/${base}" >&2
            echo "Source was left untouched: ${from_dir}" >&2
            echo "Resolve the conflict manually, then restart the container." >&2
            shopt -u dotglob nullglob
            exit 1
        fi
    done

    for item in "${entries[@]}"; do
        mv "${item}" "${to_dir}/"
    done

    shopt -u dotglob nullglob
}

resolve_doc_root() {
    require_absolute_path "APP_ROOT" "${APP_ROOT:-}"

    if [ -z "${DOC_ROOT:-}" ]; then
        DOC_ROOT="${APP_ROOT}/web"
    fi

    require_absolute_path "DOC_ROOT" "${DOC_ROOT}"
    require_absolute_path "PUBLIC_ROOT" "${PUBLIC_ROOT:-}"

    export DOC_ROOT
}

prepare_files_dir() {
    : "${FILES_DIR:=/mnt/files}"
    : "${DRUPAL_PUBLIC_FILES_SOURCE:=${FILES_DIR}/public}"

    require_absolute_path "FILES_DIR" "${FILES_DIR}"
    require_absolute_path "DRUPAL_PUBLIC_FILES_SOURCE" "${DRUPAL_PUBLIC_FILES_SOURCE}"

    mkdir -p \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${FILES_DIR}/tmp" \
        "${FILES_DIR}/config/sync"

    echo "[system-init] Files directory prepared: ${FILES_DIR}"
}

prepare_public_files() {
    : "${FILES_DIR:=/mnt/files}"
    : "${DRUPAL_PUBLIC_FILES_SOURCE:=${FILES_DIR}/public}"

    local public_files_mount
    local current_target

    require_absolute_path "DOC_ROOT" "${DOC_ROOT:-}"
    require_absolute_path "DRUPAL_PUBLIC_FILES_SOURCE" "${DRUPAL_PUBLIC_FILES_SOURCE}"

    mkdir -p "${DRUPAL_PUBLIC_FILES_SOURCE}"

    public_files_mount="${DOC_ROOT}/files"

    if [ -L "${public_files_mount}" ]; then
        current_target="$(readlink "${public_files_mount}")"

        if [ "${current_target}" = "${DRUPAL_PUBLIC_FILES_SOURCE}" ]; then
            echo "[system-init] Public files symlink already exists: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}"
            return
        fi

        echo "[system-init] Repairing public files symlink: ${public_files_mount} currently points to ${current_target}"
        rm -f "${public_files_mount}"
        ln -sfn "${DRUPAL_PUBLIC_FILES_SOURCE}" "${public_files_mount}"
        echo "[system-init] Public files symlink repaired: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}"
        return
    fi

    if [ -d "${public_files_mount}" ]; then
        if is_dir_empty "${public_files_mount}"; then
            echo "[system-init] Existing public files folder is empty. Replacing with symlink: ${public_files_mount}"
            rmdir "${public_files_mount}"
        else
            echo "[system-init] Existing public files folder contains files: ${public_files_mount}"
            echo "[system-init] Migrating contents to: ${DRUPAL_PUBLIC_FILES_SOURCE}"

            move_dir_contents_safely "${public_files_mount}" "${DRUPAL_PUBLIC_FILES_SOURCE}"

            rmdir "${public_files_mount}"

            echo "[system-init] Public files migration completed."
        fi

        ln -sfn "${DRUPAL_PUBLIC_FILES_SOURCE}" "${public_files_mount}"
        echo "[system-init] Public files symlink created: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}"
        return
    fi

    if [ -e "${public_files_mount}" ]; then
        echo "ERROR: Public files path exists but is not a directory or symlink: ${public_files_mount}" >&2
        echo "Remove it manually and restart the container." >&2
        exit 1
    fi

    ln -sfn "${DRUPAL_PUBLIC_FILES_SOURCE}" "${public_files_mount}"
    echo "[system-init] Public files symlink created: ${public_files_mount} -> ${DRUPAL_PUBLIC_FILES_SOURCE}"
}
