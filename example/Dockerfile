# ==========================
# 1) Builder Stage
# ==========================
FROM ghcr.io/your-org/drupal-builder:php83-node22-fnm AS builder

WORKDIR /app

COPY composer.json composer.lock package*.json ./
RUN npm install --omit=dev

COPY . .

RUN composer install --no-dev --optimize-autoloader --no-interaction

# Clean development artifacts
RUN cleanup-build


# ==========================
# 2) Runtime Stage
# ==========================
FROM drupal:10.3-php8.3-apache

WORKDIR /var/www/html
RUN rm -rf ./*

COPY --from=builder /app .

RUN chown -R www-data:www-data /var/www/html

EXPOSE 80
CMD ["apache2-foreground"]
