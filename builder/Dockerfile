ARG PHP=8.1
# Debian Relesases code names at https://wiki.debian.org/DebianReleases#Production_Releases
ARG OS=bookworm
# NodeJS - LTS even
ARG NODE=22
# Supplied at Build time
ARG CREATE_DATE="NA"
# Release identifier - Alpha 0
ARG VERSION=A-0

FROM php:${PHP}-${OS}

LABEL org.opencontainers.image.title="PHP Builder"
LABEL org.opencontainers.image.description="Builder Image with PHP $PHP, Composer and NodeJS $Node on $OS"
LABEL org.opencontainers.image.authors="Majed Al-Chatti"
LABEL org.opencontainers.image.source="https://github.com/alchatti/docker-php"
LABEL org.opencontainers.image.documentation="https://github.com/alchatti/docker-php/build"
LABEL org.opencontainers.image.base.name="alchatti/php-builder"
LABEL org.opencontainers.image.ref.name="alchatti/php-builder:c2-p$PHP-n$NODE-$OS"
LABEL org.opencontainers.image.created=$CREATE_DATE
LABEL org.opencontainers.image.version=$VERSION

ENV NODE=${NODE}

COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Install dependencies & nodejs
RUN apt update \
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
    curl -fsSL https://deb.nodesource.com/setup_$NODE.x | bash - \
    && apt-get install -y nodejs \
    && echo "Composer version: $(composer --version)\n" \
    && echo "Node.js version: $(node --version)\n" \
    && echo "NPM version: $(npm --version)\n" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add Build cleanup tooling
COPY --chmod=+x cleanup-build.php /usr/local/bin/cleanup-build
COPY cleanup.json  /usr/local/bin/cleanup.json

WORKDIR /app
CMD ["bash"]
