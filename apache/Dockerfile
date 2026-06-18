ARG PHP=8.3
ARG OS=bookworm

FROM php:${PHP}-apache-${OS}

# Copy scripts
COPY --chmod=+x scripts/ /usr/local/bin/

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
CMD ["apache2-foreground"]
