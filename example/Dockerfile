# ==========================
# 1) Builder Stage
# ==========================
FROM alchatti/php-builder:latest AS builder

# WORKDIR /app

COPY composer.json composer.lock package*.json ./
RUN npm install --omit=dev

COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction

# Clean development artifacts
RUN cleanup-build


# ==========================
# 2) Runtime Stage
# ==========================
FROM alchatti/drupal-fpm-apache:latest

# WORKDIR /var/www/html
COPY --from=builder --chown=www-data:www-data /app/ ./
