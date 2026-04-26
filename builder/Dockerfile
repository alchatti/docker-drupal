ARG PHP=8.2
# Debian Relesases code names at https://wiki.debian.org/DebianReleases#Production_Releases
ARG DEBIAN=bullseye

FROM php:${PHP}-${DEBIAN}

ARG PHP
ARG DEBIAN
ARG NODE
ARG CREATE_DATE

LABEL org.opencontainers.image.title="Composer with Node"
LABEL org.opencontainers.image.description="CI Builder Image with PHP $PHP, Composer and NodeJS $NODE"
LABEL org.opencontainers.image.authors="Majed Al-Chatti"
LABEL org.opencontainers.image.source="https://github.com/alchatti/ci-composer-node"
LABEL org.opencontainers.image.documentation="https://github.com/alchatti/ci-composer-node"
LABEL org.opencontainers.image.base.name="alchatti/ci-composer-node"
LABEL org.opencontainers.image.ref.name="alchatti/ci-composer-node:p$PHP-n$NODE-$DEBIAN"
LABEL org.opencontainers.image.created=$CREATE_DATE

ENV NODE=${NODE:-22}

# Install dependencies
RUN curl -fsSL https://deb.nodesource.com/setup_$NODE.x | bash - \
    && apt-get update && apt-get install -y \
    curl unzip ca-certificates git bash \
    && apt-get install -y nodejs \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    ## Clean Up
    && echo "Composer version: $(composer --version)\n" \
    && echo "Node.js version: $(node --version)\n" \
    && echo "NPM version: $(npm --version)\n" \
    && rm -rf /var/lib/apt/lists/*

# Add Build Cleanup tooling
COPY cleanup-build.php /usr/local/bin/cleanup-build
COPY cleanup.json  /usr/local/bin/cleanup.json
RUN chmod +x /usr/local/bin/cleanup-build

WORKDIR /app
CMD ["bash"]
