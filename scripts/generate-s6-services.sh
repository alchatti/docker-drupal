#!/usr/bin/env bash
set -euo pipefail

echo "[s6-setup] Generating s6-overlay v3 service definitions for Apache and PHP-FPM..."

# Base directory for s6-overlay user configuration
S6_DIR="/etc/s6-overlay/s6-rc.d"

# Create directories for both services using brace expansion
mkdir -p "${S6_DIR}"/{apache/dependencies.d,php-fpm}

# ------------------------------------------------------------------------------
# PHP-FPM Service Configuration
# ------------------------------------------------------------------------------
cat << 'EOF' > "${S6_DIR}/php-fpm/type"
longrun
EOF

cat << 'EOF' > "${S6_DIR}/php-fpm/run"
#!/bin/sh
# Execute PHP-FPM in the foreground
exec php-fpm -F
EOF

# ------------------------------------------------------------------------------
# Apache Service Configuration
# ------------------------------------------------------------------------------
cat << 'EOF' > "${S6_DIR}/apache/type"
longrun
EOF

cat << 'EOF' > "${S6_DIR}/apache/run"
#!/bin/sh
# Flush stale PID file if container restarted uncleanly
rm -f /var/run/apache2/apache2.pid

# Source Apache environment variables and start in foreground
. /etc/apache2/envvars
exec apache2 -D FOREGROUND
EOF

# ------------------------------------------------------------------------------
# Define Dependency: Apache requires PHP-FPM socket to exist before starting
# ------------------------------------------------------------------------------
touch "${S6_DIR}/apache/dependencies.d/php-fpm"

# ------------------------------------------------------------------------------
# Add to the 'user' bundle
# ------------------------------------------------------------------------------
# In s6 v3, user-defined services must belong to the 'user' or 'default' bundle
mkdir -p "${S6_DIR}/user/contents.d"
touch "${S6_DIR}/user/contents.d/apache"
touch "${S6_DIR}/user/contents.d/php-fpm"

echo "[s6-setup] s6-overlay architecture generation complete."
