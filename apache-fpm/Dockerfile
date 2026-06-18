# WIP
ARG PHP='8.5'
ARG OS='bookworm'
ARG BASE_IMAGE="php:${PHP}-fpm-${OS}"

#! S6 Build
FROM ${BASE_IMAGE} AS s6-build

ARG S6_OVERLAY_VERSION="3.2.1.0"
ARG TARGETARCH

RUN set -eux; \
# --- s6-overlay install (map TARGETARCH -> s6 arch) ---
  case "$TARGETARCH" in \
  amd64) s6arch="x86_64" ;; \
  arm64) s6arch="aarch64" ;; \
  *) echo "Unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  curl -fsSL -o /tmp/s6-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
  curl -fsSL -o /tmp/s6-arch.tar.xz   "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${s6arch}.tar.xz"; \
  tar -C / -Jxpf /tmp/s6-noarch.tar.xz; \
  tar -C / -Jxpf /tmp/s6-arch.tar.xz;

#! Image Build
FROM ${BASE_IMAGE}

# 1. Install Apache
RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 \
    && rm -rf /var/lib/apt/lists/*
    
# Copy scripts
COPY --chmod=+x scripts/ /usr/local/bin/

# Copy s6-overlay from s6-build
COPY --from=s6-build /opt/s6/ /

# Create PHP runtime dirs with www-data ownership
RUN mkdir -p /var/run/php \
  chown -R www-data:www-data /var/run/php

# 4. Create the PHP-FPM socket configuration
RUN cat << 'EOF' > /usr/local/etc/php-fpm.d/zz-docker.conf
[www]
listen = /var/run/php/php-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
EOF
 
# Install PHP dependencies and runtime tools
RUN install-php-dependencies.sh
#TODO: Switch this base & variants stage builds
RUN install-runtimes.sh --mariadb

# Configure Apache + Drupal runtime
RUN configure-drupal-runtime.sh

# Shared PHP runtime config scan path
ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/_config/php

# Global Composer/Drush shortcut path
ENV PATH="/var/www/html/vendor/bin:${PATH}"

# Apache environment overrides for non-root execution
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2

# Working directory
WORKDIR /var/www/html

# Drop privileges
USER www-data

EXPOSE 8080

# Configure Docker to run the healthcheck
# Note: Adjust start-period if your container runs database updates on startup
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD ["healthcheck.sh"]

ENTRYPOINT ["docker-entrypoint-apache.sh"]
CMD ["/init"]
