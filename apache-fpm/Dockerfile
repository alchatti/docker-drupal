# Drupal runtime: Apache event MPM + PHP-FPM + s6-overlay
# Build example:
#   docker build --build-arg PHP=8.4 --build-arg OS=bookworm -t alchatti/drupal:8.4-apache-fpm-s6 .

ARG PHP=8.4
ARG OS=bookworm
ARG BASE_IMAGE=php:${PHP}-fpm-${OS}

FROM ${BASE_IMAGE} AS s6-build

ARG S6_OVERLAY_VERSION=3.2.2.0
ARG TARGETARCH

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates curl xz-utils; \
  rm -rf /var/lib/apt/lists/*; \
  case "${TARGETARCH}" in \
    amd64) s6arch="x86_64" ;; \
    arm64) s6arch="aarch64" ;; \
    *) echo "Unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
  esac; \
  curl -fsSL -o /tmp/s6-noarch.tar.xz \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
  curl -fsSL -o /tmp/s6-arch.tar.xz \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${s6arch}.tar.xz"; \
  mkdir -p /s6-rootfs; \
  tar -C /s6-rootfs -Jxpf /tmp/s6-noarch.tar.xz; \
  tar -C /s6-rootfs -Jxpf /tmp/s6-arch.tar.xz; \
  rm -f /tmp/s6-noarch.tar.xz /tmp/s6-arch.tar.xz

FROM ${BASE_IMAGE}

ARG PHP
ARG OS

LABEL org.opencontainers.image.title="Drupal Apache PHP-FPM s6 runtime" \
  org.opencontainers.image.description="Rootless Drupal runtime using Apache event MPM, PHP-FPM and s6-overlay" \
  org.opencontainers.image.base.name="php:${PHP}-fpm-${OS}" \
  org.opencontainers.image.source="https://github.com/alchatti/docker-drupal"

ENV DRUPAL_RUNTIME_MODE=s6-fpm \
  DRUPAL_SUBDIR= \
  DRUPAL_PUBLIC_DIR=web \
  APACHE_PORT=8080 \
  APP_ROOT=/app \
  DOC_ROOT= \
  PUBLIC_ROOT=/var/www/html \
  CONFIG_ROOT=/_config \
  APACHE_CONFIG_DIR=/_config/apache \
  FPM_RUNTIME_CONF=/usr/local/etc/php-fpm.d/zz-runtime.conf \
  FPM_SOCKET=/var/run/php/php-fpm.sock \
  FILES_DIR=/mnt/files \
  PATH=/app/vendor/bin:${PATH} \
  S6_KEEP_ENV=1 \
  S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
  S6_RUN_DIR=/var/run/apache2 \
  S6_LOG_DIR=/var/log/apache2 \
  APACHE_RUN_USER=www-data \
  APACHE_RUN_GROUP=www-data \
  APACHE_CONFDIR=/etc/apache2 \
  APACHE_PID_FILE=/var/run/apache2/apache2.pid \
  APACHE_RUN_DIR=/var/run/apache2 \
  APACHE_LOCK_DIR=/var/lock/apache2 \
  APACHE_LOG_DIR=/var/log/apache2 \
  TZ=Asia/Dubai \
  PHP_MEMORY_LIMIT=512M \
  PHP_OPCACHE_MEMORY_CONSUMPTION=512 \
  PHP_UPLOAD_MAX_FILESIZE=64M \
  PHP_POST_MAX_SIZE=64M \
  PHP_MAX_EXECUTION_TIME=120 \
  PHP_MAX_INPUT_VARS=4000 \
  PHP_OUTPUT_BUFFERING=true \
  PHP_REALPATH_CACHE_SIZE=4096K \
  PHP_REALPATH_CACHE_TTL=600 \
  PHP_OPCACHE_ENABLE=1 \
  PHP_OPCACHE_ENABLE_CLI=1 \
  PHP_OPCACHE_INTERNED_STRINGS_BUFFER=16 \
  PHP_OPCACHE_MAX_ACCEL_FILES=50000 \
  PHP_OPCACHE_VALIDATE_TIMESTAMPS=0 \
  PHP_OPCACHE_REVALIDATE_FREQ=60 \
  DEFAULT_MEMORY_LIMIT_MB=1024 \
  USE_HOST_MEMORY_WHEN_UNLIMITED=0 \
  RESERVED_MEMORY_MIN_MB=128 \
  RESERVED_MEMORY_FRACTION=10 \
  PHP_MEMORY_LIMIT_MIN_MB=128 \
  PHP_MEMORY_LIMIT_MAX_MB=768 \
  OPCACHE_MIN_MB=96 \
  OPCACHE_MAX_MB=256 \
  AVG_PHP_THREAD_MB=120 \
  HEADROOM_MB=64 \
  MIN_PHP_THREADS=2 \
  MAX_PHP_THREADS_CAP=256 \
  START_WORKERS=2 \
  MIN_SPARE_WORKERS=2 \
  MAX_SPARE_WORKERS=10 \
  MAX_REQUESTS_PER_CHILD=5000 \
  APACHE_WORKERS_MULTIPLIER=4 \
  APACHE_MAX_REQUEST_WORKERS_CAP=400

RUN set -eux; \
  apt-get update; \
  apt-get upgrade -y; \
  apt-get install -y --no-install-recommends \
    apache2 \
    bash \
    ca-certificates \
    curl; \
  rm -rf /var/lib/apt/lists/*

COPY --from=s6-build /s6-rootfs/ /
COPY --chmod=755 scripts/ /usr/local/bin/

RUN set -eux; \
  install-php-dependencies.sh; \
  configure-drupal-runtime.sh; \
  generate-s6-services.sh; \
  touch "${FPM_RUNTIME_CONF}"; \
  chown -R www-data:www-data \
    "${APP_ROOT}" \
    /var/www \
    "${CONFIG_ROOT}" \
    "${FILES_DIR}" \
    /var/run/apache2 \
    /var/lock/apache2 \
    /var/log/apache2 \
    /var/run/php \
    /etc/apache2 \
    /etc/s6-overlay \
    "${FPM_RUNTIME_CONF}"; \
  chmod +x \
    /etc/s6-overlay/s6-rc.d/php-fpm/run \
    /etc/s6-overlay/s6-rc.d/apache/run ; \
    # Runtime Dependency
    install-runtimes.sh --mariadb
    

WORKDIR /app

USER www-data

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["healthcheck.sh"]

ENTRYPOINT ["docker-entrypoint-apache.sh"]
CMD ["/init"]
