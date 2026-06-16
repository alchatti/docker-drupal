# Global Scope Arguments
ARG PHP=8.1
### Debian Relesases code names at https://wiki.debian.org/DebianReleases#Production_Releases
ARG OS=bookworm
### NodeJS - LTS even
ARG NODE=22
### Supplied at Build time
ARG CREATE_DATE="NA"
### Release identifier - Alpha 0
ARG VERSION=A-0

# --- Base Stage Boundary ---
FROM php:${PHP}-${OS}

# Local Stage Scoped
ARG PHP
ARG OS
ARG NODE
ARG CREATE_DATE
ARG VERSION

LABEL org.opencontainers.image.title="PHP Builder" \
      org.opencontainers.image.description="Builder Image with PHP $PHP, Composer and NodeJS $NODE on $OS" \
      org.opencontainers.image.authors="Majed Al-Chatti" \
      org.opencontainers.image.source="https://github.com/alchatti/docker-php" \
      org.opencontainers.image.documentation="https://github.com/alchatti/docker-php/build" \
      org.opencontainers.image.base.name="alchatti/php-builder" \
      org.opencontainers.image.ref.name="alchatti/php-builder:c2-p$PHP-n$NODE-$OS" \
      org.opencontainers.image.created=$CREATE_DATE \
      org.opencontainers.image.version=$VERSION

ENV NODE_VERSION=${NODE}

# Composer from Official image
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Copy all scripts to /usr/local/bin/ with execution permissions
COPY --chmod=+x scripts/ /usr/local/bin/

# System Dependencies, Ext Extensions, & NodeJS Core
RUN install-php-dependencies.sh
RUN install-builder-dependencies.sh "${NODE_VERSION}"

# Post-installation system verification
RUN echo "Composer version: $(composer --version)" \
    && echo "Node.js version: $(node --version)" \
    && echo "NPM version: $(npm --version)"
    
COPY --chmod=+x cleanup-build.php /usr/local/bin/cleanup-build
COPY cleanup.json /usr/local/bin/cleanup.json

WORKDIR /app
CMD ["bash"]
