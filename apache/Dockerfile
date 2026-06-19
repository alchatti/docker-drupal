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
    PATH=/var/www/html/vendor/bin:${PATH}

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
