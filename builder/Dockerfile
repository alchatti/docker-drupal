# Global Scope Arguments
ARG PHP=8.1
ARG OS=bookworm
ARG NODE_VERSION=22
ARG CREATE_DATE="NA"
ARG VERSION=A-0

FROM php:${PHP}-${OS}

ARG PHP
ARG OS
ARG NODE_VERSION
ARG CREATE_DATE
ARG VERSION

LABEL org.opencontainers.image.title="PHP Builder" \
      org.opencontainers.image.description="Builder Image with PHP $PHP, Composer and NodeJS $NODE_VERSION on $OS" \
      org.opencontainers.image.authors="Majed Al-Chatti" \
      org.opencontainers.image.source="https://github.com/alchatti/docker-php" \
      org.opencontainers.image.documentation="https://github.com/alchatti/docker-php/build" \
      org.opencontainers.image.base.name="alchatti/php-builder" \
      org.opencontainers.image.ref.name="alchatti/php-builder:c2-p$PHP-n$NODE_VERSION-$OS" \
      org.opencontainers.image.created=$CREATE_DATE \
      org.opencontainers.image.version=$VERSION

ENV NODE=${NODE_VERSION}

# Composer from official image
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Copy script to /usr/local/bin/ with execution permissions
COPY --chmod=+x scripts/install-php-dependencies.sh /usr/local/bin/install-php-dependencies.sh
COPY --chmod=+x scripts/verify-builder.sh /usr/local/bin/verify-builder.sh

# Install Node.js from official Node.js binary tarball, then install PHP deps
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      curl \
      ca-certificates \
      xz-utils; \
    # NodeJS 
    curl -fsSL "https://deb.nodesource.com/setup_${NODE}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs; \
    node --version; \
    npm --version; \
    # Drupal Requirement with cleanup script
    install-php-dependencies.sh

# Post-installation system verification
RUN set -eux; \
    composer --version; \
    node --version; \
    npm --version

COPY --chmod=+x builder/cleanup-build.php /usr/local/bin/cleanup-build
COPY builder/cleanup.json /usr/local/bin/cleanup.json

WORKDIR /app
CMD ["bash"]
