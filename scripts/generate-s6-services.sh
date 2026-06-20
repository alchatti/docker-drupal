#!/usr/bin/env bash
set -euo pipefail

# Build-time generation of s6-overlay v3 service definitions.

set -x

S6_DIR="${S6_DIR:-/etc/s6-overlay/s6-rc.d}"

mkdir -p \
    "${S6_DIR}/php-fpm" \
    "${S6_DIR}/apache/dependencies.d" \
    "${S6_DIR}/user/contents.d"

cat > "${S6_DIR}/php-fpm/type" <<'EOF_TYPE'
longrun
EOF_TYPE

cat > "${S6_DIR}/php-fpm/run" <<'EOF_RUN'
#!/command/with-contenv sh
set -eu
exec php-fpm -F
EOF_RUN

cat > "${S6_DIR}/apache/type" <<'EOF_TYPE'
longrun
EOF_TYPE

cat > "${S6_DIR}/apache/run" <<'EOF_RUN'
#!/command/with-contenv sh
set -eu
rm -f /var/run/apache2/apache2.pid
: "${APACHE_CONFDIR:=/etc/apache2}"
. /etc/apache2/envvars
exec apache2 -D FOREGROUND
EOF_RUN

touch "${S6_DIR}/apache/dependencies.d/php-fpm"
touch "${S6_DIR}/user/contents.d/php-fpm"
touch "${S6_DIR}/user/contents.d/apache"

chmod +x "${S6_DIR}/php-fpm/run" "${S6_DIR}/apache/run"

echo "[s6-setup] Generated s6 services: php-fpm, apache."
