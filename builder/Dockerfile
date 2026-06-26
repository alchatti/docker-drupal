# Global Scope Arguments
ARG PHP=8.4
ARG OS=bookworm
ARG NODE=22
ARG CREATE_DATE="NA"
ARG VERSION=A-0

FROM php:${PHP}-${OS}

ARG PHP
ARG OS
ARG NODE
ARG CREATE_DATE
ARG VERSION

LABEL org.opencontainers.image.title="PHP Builder" \
      org.opencontainers.image.description="Builder Image with PHP $PHP, Composer and NodeJS $NODE on $OS" \
      org.opencontainers.image.authors="Majed Al-Chatti" \
      org.opencontainers.image.source="https://github.com/alchatti/docker-drupal" \
      org.opencontainers.image.documentation="https://github.com/alchatti/docker-drupal" \
      org.opencontainers.image.base.name="alchatti/php-builder" \
      org.opencontainers.image.ref.name="alchatti/php-builder:c2-p$PHP-n$NODE-$OS" \
      org.opencontainers.image.created=$CREATE_DATE \
      org.opencontainers.image.version=$VERSION

ENV NODE=${NODE} \
    HOME=/var/www \
    COMPOSER_HOME=/var/www/.composer \
    NPM_CONFIG_CACHE=/var/www/.npm \
    PATH=/app/vendor/bin:/var/www/.composer/vendor/bin:${PATH}

# Composer from official image
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Copy scripts to /usr/local/bin with execution permissions
COPY --chmod=755 scripts/install-php-dependencies.sh /usr/local/bin/install-php-dependencies.sh
COPY --chmod=755 scripts/verify-builder.sh /usr/local/bin/verify-builder.sh

# Install Node.js, PHP extensions/dependencies, and prepare writable non-root paths
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
      bash \
      curl \
      ca-certificates \
      xz-utils; \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE}.x" | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    install-php-dependencies.sh; \
    mkdir -p \
      /app \
      /var/www/.composer \
      /var/www/.npm; \
    chown -R www-data:www-data \
      /app \
      /var/www/.composer \
      /var/www/.npm; \
    rm -rf /var/lib/apt/lists/*

COPY --chmod=755 builder/cleanup-build.php /usr/local/bin/cleanup-build
COPY --chmod=644 builder/cleanup.json /usr/local/bin/cleanup.json

WORKDIR /app

USER www-data

# Post-installation system verification as root during build
RUN set -eux; \
    composer --version; \
    node --version; \
    npm --version

CMD ["bash"]
