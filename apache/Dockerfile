# Optional example for the Apache mod_php variant using the same scripts/entrypoint.
ARG PHP=8.4
ARG OS=bookworm
FROM php:${PHP}-apache-${OS}

ENV DRUPAL_RUNTIME_MODE=mod_php \
    APACHE_PORT=8080 \
    APP_ROOT=/var/www/html \
    DOC_ROOT=/var/www/html/web \
    CONFIG_ROOT=/_config \
    APACHE_CONFIG_DIR=/_config/apache \
    PHP_CONFIG_DIR=/_config/php \
    PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/_config/php \
    PATH=/var/www/html/vendor/bin:${PATH} \
    TZ=Asia/Dubai \
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
    PHP_OPCACHE_REVALIDATE_FREQ=60

COPY --chmod=755 scripts/ /usr/local/bin/

RUN set -eux; \
    install-php-dependencies.sh; \
    install-runtimes.sh --mariadb; \
    configure-drupal-runtime.sh

WORKDIR /var/www/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 CMD ["healthcheck.sh"]
ENTRYPOINT ["docker-entrypoint-apache.sh"]
CMD ["apache2-foreground"]
