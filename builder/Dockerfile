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

ENV NODE=${NODE}

# Composer from Official image
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# System Dependencies, Ext Extensions, & NodeJS Core 
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    ca-certificates \
    bash \
    libfreetype6-dev \
    libjpeg-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev \
    curl \
    gnupg \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg=/usr \
        --with-webp \
    && docker-php-ext-install -j "$(nproc)" \
        gd \
        pdo_mysql \
        pdo_pgsql \
        zip \
    # Modern Nodesource installation syntax (Avoids executing unverified scripts straight via curl)
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    # Post-installation system verification
    && echo "Composer version: $(composer --version)" \
    && echo "Node.js version: $(node --version)" \
    && echo "NPM version: $(npm --version)" \
    # Aggressive image size cleanup
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --chmod=+x cleanup-build.php /usr/local/bin/cleanup-build
COPY cleanup.json /usr/local/bin/cleanup.json

WORKDIR /app
CMD ["bash"]
