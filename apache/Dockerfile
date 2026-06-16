ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

# 1. Install scripts
COPY --chmod=+x scripts/ /usr/local/bin/

# 2. Install PHP dependencies and runtime tools
RUN install-php-dependencies.sh
RUN install-runtimes.sh --mariadb

# 3. Configure Apache + Drupal runtime
RUN configure-drupal-runtime.sh

# 4. Shared PHP runtime config scan path
ENV PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/_config/php

# 5. Global Composer/Drush shortcut path
ENV PATH="/var/www/html/vendor/bin:${PATH}"

# 6. Working directory
WORKDIR /var/www/html

# 7. Apache environment overrides for non-root execution
ENV APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2

# 8. Drop privileges
USER www-data

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint-apache.sh"]
CMD ["apache2-foreground"]
