#!/usr/bin/env bash
set -Eeuo pipefail

: "${FILES_DIR:=/mnt/files}"
: "${PAYLOAD_DIR:=/payload}"
: "${ARCHIVE_DIR:=/archive}"
: "${FACILITATOR_ACTION:=seed}"
: "${CLEAR_TARGET:=0}"
: "${ARCHIVE_NAME:=drupal-files.tar.gz}"

log() {
    echo "[files-facilitator] $*"
}

fail() {
    echo "[files-facilitator] ERROR: $*" >&2
    exit 1
}

require_absolute_path() {
    local name="$1"
    local value="$2"

    if [ -z "${value}" ]; then
        fail "${name} must not be empty."
    fi

    case "${value}" in
        /*) ;;
        *) fail "${name} must be an absolute path. Current value: ${value}" ;;
    esac
}

safe_clear_directory() {
    local target="$1"

    require_absolute_path "target" "${target}"

    case "${target}" in
        /|/mnt|/mnt/|/payload|/payload/|/archive|/archive/)
            fail "Refusing to clear unsafe directory: ${target}"
            ;;
    esac

    if [ ! -d "${target}" ]; then
        mkdir -p "${target}"
        return
    fi

    find "${target}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}

prepare_files_structure() {
    require_absolute_path "FILES_DIR" "${FILES_DIR}"
    require_absolute_path "PAYLOAD_DIR" "${PAYLOAD_DIR}"
    require_absolute_path "ARCHIVE_DIR" "${ARCHIVE_DIR}"

    mkdir -p \
        "${FILES_DIR}/public" \
        "${FILES_DIR}/private" \
        "${FILES_DIR}/tmp" \
        "${FILES_DIR}/config/sync" \
        "${PAYLOAD_DIR}" \
        "${ARCHIVE_DIR}"

    log "Files structure is ready at ${FILES_DIR}"
}

copy_payload_dir() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"

    if [ ! -d "${source_dir}" ]; then
        log "No ${label} payload found at ${source_dir}; skipping."
        return
    fi

    mkdir -p "${target_dir}"

    if [ "${CLEAR_TARGET}" = "1" ]; then
        log "CLEAR_TARGET=1; clearing ${target_dir}"
        safe_clear_directory "${target_dir}"
    fi

    log "Seeding ${label}: ${source_dir} -> ${target_dir}"
    cp -a "${source_dir}/." "${target_dir}/"
}

init_volume() {
    prepare_files_structure
    log "Initialization completed."
}

seed_volume() {
    prepare_files_structure

    copy_payload_dir "${PAYLOAD_DIR}/public" "${FILES_DIR}/public" "public files"
    copy_payload_dir "${PAYLOAD_DIR}/private" "${FILES_DIR}/private" "private files"
    copy_payload_dir "${PAYLOAD_DIR}/tmp" "${FILES_DIR}/tmp" "temporary files"
    copy_payload_dir "${PAYLOAD_DIR}/config/sync" "${FILES_DIR}/config/sync" "config sync"

    log "Seed completed."
}

archive_volume() {
    local archive_path

    prepare_files_structure

    archive_path="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

    log "Creating archive: ${archive_path}"
    tar -C "${FILES_DIR}" -czf "${archive_path}" .
    log "Archive created: ${archive_path}"
}

restore_volume() {
    local archive_path

    prepare_files_structure

    archive_path="${ARCHIVE_DIR}/${ARCHIVE_NAME}"

    if [ ! -f "${archive_path}" ]; then
        fail "Archive not found: ${archive_path}"
    fi

    if [ "${CLEAR_TARGET}" = "1" ]; then
        log "CLEAR_TARGET=1; clearing ${FILES_DIR} before restore."
        safe_clear_directory "${FILES_DIR}"
        prepare_files_structure
    fi

    log "Restoring archive: ${archive_path} -> ${FILES_DIR}"
    tar -C "${FILES_DIR}" -xzf "${archive_path}"
    prepare_files_structure
    log "Restore completed."
}

status_volume() {
    prepare_files_structure

    log "Status"
    echo "FILES_DIR=${FILES_DIR}"
    echo "PAYLOAD_DIR=${PAYLOAD_DIR}"
    echo "ARCHIVE_DIR=${ARCHIVE_DIR}"
    echo "ARCHIVE_NAME=${ARCHIVE_NAME}"
    echo

    log "Top-level files directory structure"
    find "${FILES_DIR}" -maxdepth 3 -mindepth 0 -print | sort
}

show_usage() {
    cat <<USAGE
Usage:
  files-facilitator.sh [init|seed|archive|restore|status]

Actions:
  init      Create the expected Drupal files directory structure.
  seed      Copy payload files into the Drupal files volume.
  archive   Create a tar.gz archive from the Drupal files volume.
  restore   Restore a tar.gz archive into the Drupal files volume.
  status    Show the current directory structure.

Environment:
  FILES_DIR=${FILES_DIR}
  PAYLOAD_DIR=${PAYLOAD_DIR}
  ARCHIVE_DIR=${ARCHIVE_DIR}
  ARCHIVE_NAME=${ARCHIVE_NAME}
  CLEAR_TARGET=${CLEAR_TARGET}

Notes:
  - This container runs as www-data.
  - It is designed for Docker named volumes mounted at /mnt/files.
  - It does not repair ownership and does not run chown.
USAGE
}

action="${1:-${FACILITATOR_ACTION}}"

case "${action}" in
    init)
        init_volume
        ;;
    seed)
        seed_volume
        ;;
    archive)
        archive_volume
        ;;
    restore)
        restore_volume
        ;;
    status)
        status_volume
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage >&2
        fail "Unknown action: ${action}"
        ;;
esac
