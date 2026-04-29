FROM serversideup/php:8.4-fpm-apache

USER root

RUN apt-get update \
  && apt install -y --no-install-recommends \
  unzip \
  ca-certificates \
  bash \
  libfreetype6-dev \
  libjpeg-dev \
  libpng-dev \
  libpq-dev \
  libwebp-dev \
  libzip-dev \
  ; \
  \
  docker-php-ext-configure gd \
  --with-freetype \
  --with-jpeg=/usr \
  --with-webp \
  ; \
  \
  docker-php-ext-install -j "$(nproc)" \
  gd \
  pdo_mysql \
  pdo_pgsql \
  zip \
  ; \
  apt-get clean \
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
  } > /usr/local/etc/php/conf.d/zzz-drupal-production.ini

# App code will be copied later
WORKDIR /var/www/html

USER www-data
