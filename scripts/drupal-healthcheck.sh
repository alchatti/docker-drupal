#!/usr/bin/env bash
set -euo pipefail

# Global Environment Variable
cd "$DOC_ROOT"

# 1. Check Apache/PHP locally
curl -fsS --max-time 5 http://127.0.0.1/ >/dev/null

# 2. Check Drupal bootstrap and database
drush status bootstrap --field=bootstrap | grep -q "Successful"

# 3. Run simple DB query through Drupal
drush sql:query "SELECT 1;" >/dev/null
