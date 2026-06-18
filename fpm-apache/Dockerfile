ARG PHP=8.3
ARG OS=bookworm

FROM serversideup/php:${PHP}-fpm-apache-${OS}

USER root

# 1. Install scripts
COPY --chmod=+x scripts/ /usr/local/bin/

# 2. Install PHP dependencies and runtime tools
RUN install-php-dependencies.sh
RUN install-runtimes.sh --mariadb

ENV PATH="/var/www/html/vendor/bin:${PATH}"

# Drupal production-friendly PHP settings
RUN { \
  echo "memory_limit=256M"; \
  echo "upload_max_filesize=64M"; \
  echo "post_max_size=64M"; \
  echo "max_execution_time=120"; \
  echo "opcache.enable=1"; \
  echo "opcache.enable_cli=1"; \
  echo "opcache.memory_consumption=256"; \
  echo "opcache.interned_strings_buffer=16"; \
  echo "opcache.max_accelerated_files=20000"; \
  echo "opcache.validate_timestamps=0"; \
  } > /usr/local/etc/php/conf.d/zzz-drupal-production.ini

# Create mount point and set permissions
RUN mkdir -p /mnt/files/{public,private,tmp,config/sync}\
    && chown -R www-data:www-data /mnt/files \
    && chmod -R 755 /mnt/files

# App code will be copied later
WORKDIR /var/www/html

USER www-data

# Configure Docker to run the healthcheck
# Note: Adjust start-period if your container runs database updates on startup
HEALTHCHECK --interval=20s --timeout=5s --start-period=30s --retries=3 \
  CMD ["healthcheck.sh"]
