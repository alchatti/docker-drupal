# ==========================
# 1) Builder Stage
# ==========================
FROM alchatti/drupal:builder AS builder

WORKDIR /app

# Copy the Drupal application source into the builder image.
# The application is expected to use /app/web as the public docroot.
COPY ./ ./

RUN set -eux; \
  composer install --no-dev --optimize-autoloader --no-interaction; \
  # Remove files and configure Symlink for volume mount
  # Use facilitator Image for files migration
  rm -rf /app/web/files; \
  ln -sfn /mnt/files/public /app/web/files

# ==========================
# 2) Runtime Stage
# ==========================
FROM alchatti/drupal:apache-fpm

COPY --from=builder --chown=www-data:www-data /app/ ./
