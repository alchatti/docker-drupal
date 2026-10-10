#!/usr/bin/env bash
set -euo pipefail

# Build-time Drupal PHP extensions for official Debian-based PHP images.
# Simple mode: installed packages remain installed.

set -x

if ! command -v docker-php-ext-install >/dev/null 2>&1; then
    echo "ERROR: docker-php-ext-install was not found. Use an official PHP Docker base image." >&2
    exit 1
fi

apt-get update

apt-get install -y --no-install-recommends \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    libwebp-dev \
    libzip-dev

docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp

docker-php-ext-install -j "$(nproc)" \
    gd \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    pdo_pgsql \
    zip

rm -rf /var/lib/apt/lists/*
