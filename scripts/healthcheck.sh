#!/usr/bin/env bash
set -euo pipefail

APACHE_PORT="${APACHE_PORT:-8080}"
HEALTHCHECK_PATH="${HEALTHCHECK_PATH:-/}"
DOC_ROOT="${DOC_ROOT:-/app/web}"

curl -fsSL --max-time 4 "http://127.0.0.1:${APACHE_PORT}${HEALTHCHECK_PATH}" >/dev/null

# Optional deep Drupal/DB check. Keep disabled by default to avoid restarting
# a healthy web container during DB maintenance or Drupal update windows.
if [ "${HEALTHCHECK_DEEP:-0}" = "1" ]; then
    cd "${DOC_ROOT}"

    if ! command -v drush >/dev/null 2>&1; then
        echo "Healthcheck failed: drush not found." >&2
        exit 1
    fi

    if ! drush status --format=json 2>/dev/null | grep -q '"bootstrap": "Successful"'; then
        echo "Healthcheck failed: Drupal failed to bootstrap." >&2
        exit 1
    fi

    if ! drush sql:query "SELECT 1;" >/dev/null 2>&1; then
        echo "Healthcheck failed: database SELECT verification failed." >&2
        exit 1
    fi
fi
