#!/usr/bin/env bash
set -euo pipefail

: "${FILES_DIR:=/mnt/files}"
: "${PAYLOAD_DIR:=/payload}"
: "${ARCHIVE_DIR:=/archive}"
: "${FACILITATOR_ACTION:=seed}"
: "${CLEAR_TARGET:=0}"
: "${FIX_OWNERSHIP:=1}"
: "${FILES_UID:=33}"
: "${FILES_GID:=33}"
: "${ARCHIVE_NAME:=drupal-files.tar.gz}"

ACTION="${1:-${FACILITATOR_ACTION}}"

require_absolute_path() {
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

safe_clear_files_dir() {
    case "${FILES_DIR}" in
        ""|"/"|"/mnt"|"/mnt/"|"/app"|"/app/")
            echo "ERROR: Refusing to clear unsafe FILES_DIR=${FILES_DIR}" >&2
            exit 1
            ;;
    esac

    find "${FILES_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

init_structure() {
    mkdir -p \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${FILES_DIR}/tmp" \
        "${FILES_DIR}/config/sync"

    echo "[facilitator] Files structure ready under ${FILES_DIR}"
}

copy_tree_if_present() {
    local source_dir="$1"
    local target_dir="$2"

    if [ ! -d "${source_dir}" ]; then
        return
    fi

    mkdir -p "${target_dir}"

    if [ -z "$(find "${source_dir}" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        echo "[facilitator] Payload directory is empty, skipping: ${source_dir}"
        return
    fi

    echo "[facilitator] Copying ${source_dir}/ -> ${target_dir}/"
    cp -a "${source_dir}/." "${target_dir}/"
}

seed_payload() {
    init_structure

    if [ "${CLEAR_TARGET}" = "1" ]; then
        echo "[facilitator] CLEAR_TARGET=1, clearing ${FILES_DIR} before seeding."
        safe_clear_files_dir
        init_structure
    fi

    copy_tree_if_present "${PAYLOAD_DIR}/public" "${FILES_DIR}/public"
    copy_tree_if_present "${PAYLOAD_DIR}/private" "${FILES_DIR}/private"
    copy_tree_if_present "${PAYLOAD_DIR}/tmp" "${FILES_DIR}/tmp"
    copy_tree_if_present "${PAYLOAD_DIR}/config/sync" "${FILES_DIR}/config/sync"

    if [ -f "${PAYLOAD_DIR}/${ARCHIVE_NAME}" ]; then
        echo "[facilitator] Found payload archive: ${PAYLOAD_DIR}/${ARCHIVE_NAME}"
        restore_archive "${PAYLOAD_DIR}/${ARCHIVE_NAME}"
    fi
}

archive_files() {
    init_structure
    mkdir -p "${ARCHIVE_DIR}"

    local output="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

    echo "[facilitator] Creating archive: ${output}"
    tar -C "${FILES_DIR}" -czf "${output}" .
    echo "[facilitator] Archive created: ${output}"
}

restore_archive() {
    local archive_file="${1:-${ARCHIVE_DIR}/${ARCHIVE_NAME}}"

    if [ ! -f "${archive_file}" ]; then
        echo "ERROR: Archive file not found: ${archive_file}" >&2
        exit 1
    fi

    init_structure

    if [ "${CLEAR_TARGET}" = "1" ]; then
        echo "[facilitator] CLEAR_TARGET=1, clearing ${FILES_DIR} before restore."
        safe_clear_files_dir
        init_structure
    fi

    echo "[facilitator] Restoring archive ${archive_file} into ${FILES_DIR}"
    tar -C "${FILES_DIR}" -xzf "${archive_file}"
    echo "[facilitator] Restore completed."
}

fix_ownership() {
    if [ "${FIX_OWNERSHIP}" != "1" ]; then
        echo "[facilitator] Ownership fix disabled."
        return
    fi

    echo "[facilitator] Setting ownership ${FILES_UID}:${FILES_GID} on ${FILES_DIR}"
    chown -R "${FILES_UID}:${FILES_GID}" "${FILES_DIR}"
}

print_status() {
    init_structure

    echo "[facilitator] Status"
    echo "FILES_DIR=${FILES_DIR}"
    echo "PAYLOAD_DIR=${PAYLOAD_DIR}"
    echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
    echo "ARCHIVE_NAME=${ARCHIVE_NAME}"
    find "${FILES_DIR}" -maxdepth 3 -mindepth 1 -print | sort
}

require_absolute_path "FILES_DIR" "${FILES_DIR}"
require_absolute_path "PAYLOAD_DIR" "${PAYLOAD_DIR}"
require_absolute_path "ARCHIVE_DIR" "${ARCHIVE_DIR}"

case "${ACTION}" in
    init)
        init_structure
        fix_ownership
        ;;
    seed)
        seed_payload
        fix_ownership
        ;;
    archive)
        archive_files
        ;;
    restore)
        restore_archive "${2:-${ARCHIVE_DIR}/${ARCHIVE_NAME}}"
        fix_ownership
        ;;
    status)
        print_status
        ;;
    *)
        echo "ERROR: Unsupported facilitator action: ${ACTION}" >&2
        echo "Supported actions: init, seed, archive, restore, status" >&2
        exit 1
        ;;
esac
