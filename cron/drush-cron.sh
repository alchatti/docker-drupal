#!/usr/bin/env bash
# Read drush.cron and then execute one by one
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST_FILE="${BASE_DIR}/drush.cron"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Drupal cron runner"

while IFS= read -r folder || [ -n "${folder}" ]; do
    # Skip empty lines and comments
    [ -z "${folder}" ] && continue
    case "${folder}" in \#*) continue ;; esac

    SITE_DIR="${BASE_DIR}/${folder}"
    COMPOSE_FILE="${SITE_DIR}/compose.yml"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running cron for: ${folder}"

    if [ ! -f "${COMPOSE_FILE}" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Missing compose.yml for ${folder}"
        continue
    fi

    cd "${SITE_DIR}" || continue

    if docker compose run --rm cron; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: ${folder}"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED: ${folder}"
    fi

done < "${LIST_FILE}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Drupal cron runner completed"
