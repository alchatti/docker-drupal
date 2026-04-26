ARG PHP
# Debian Relesases code names at https://wiki.debian.org/DebianReleases#Production_Releases
ARG OS_VARIANT
# NodeJS - LTS even 
ARG NODE
# Supplied at Build time
ARG CREATE_DATE
# Release identifier - Alpha 0
ARG VERSION=A-0

FROM php:${PHP}-${OS_VARIANT}

LABEL org.opencontainers.image.title="PHP Builder"
LABEL org.opencontainers.image.description="Builder Image with PHP $PHP, Composer and NodeJS $Node on $OS_VARIANT"
LABEL org.opencontainers.image.authors="Majed Al-Chatti"
LABEL org.opencontainers.image.source="https://github.com/alchatti/docker-php"
LABEL org.opencontainers.image.documentation="https://github.com/alchatti/docker-php/build"
LABEL org.opencontainers.image.base.name="alchatti/php-builder"
LABEL org.opencontainers.image.ref.name="alchatti/php-builder:c2-p$PHP-n$NODE-$OS_VARIANT"
LABEL org.opencontainers.image.created=$CREATE_DATE
LABEL org.opencontainers.image.version=$VERSION

ENV NODE=${NODE:-24}

COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Install dependencies & nodejs
RUN curl -fsSL https://deb.nodesource.com/setup_$NODE.x | bash - \
    && apt-get update && apt-get install -y \
    && unzip ca-certificates bash \
    && apt-get install -y nodejs \
    && echo "Composer version: $(composer --version)\n" \
    && echo "Node.js version: $(node --version)\n" \
    && echo "NPM version: $(npm --version)\n" \
    && rm -rf /var/lib/apt/lists/*

# Add Build cleanup tooling
COPY --chmod=+x cleanup-build.php /usr/local/bin/cleanup-build
COPY cleanup.json  /usr/local/bin/cleanup.json

WORKDIR /app
CMD ["bash"]
