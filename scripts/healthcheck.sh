#!/usr/bin/env bash
set -euo pipefail

# Global Environment Variable
cd "$DOC_ROOT"

# 1. Verify Drupal can bootstrap
if ! drush status --format=json 2>/dev/null | grep -q '"bootstrap": "Successful"'; then
  echo "Healthcheck failed: Drupal failed to bootstrap." >&2
  exit 1
fi

# 2. Live Database Verification: Force a SELECT query through Drush
# This ensures the DB user has active permissions and the engine is responding.
if ! drush sql:query "SELECT 1;" &> /dev/null; then
  echo "Healthcheck failed: Database connection select verification failed." >&2
  exit 1
fi

# 3. Web Routing Verification: Ensure HTTP traffic is successfully serving
if ! curl -fs http://localhost:8080/ > /dev/null; then
  echo "Healthcheck failed: Web server is not responding to HTTP requests." >&2
  exit 1
fi

# All checks passed successfully
exit 0
