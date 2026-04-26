FROM serversideup/php:8.4-fpm-apache

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      unzip \
      rsync \
      default-mysql-client \
      libjpeg62-turbo \
      libpng16-16 \
      libwebp7 \
      libfreetype6 \
      libzip5 \
      imagemagick \
    && install-php-extensions \
      bcmath \
      gd \
      intl \
      opcache \
      pdo_mysql \
      zip \
      exif \
      redis \
      imagick \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
    } > /usr/local/etc/php/conf.d/99-drupal-production.ini

# App code will be copied later
WORKDIR /var/www/html

USER www-data
