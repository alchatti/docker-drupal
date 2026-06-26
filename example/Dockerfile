# Example Drupal application image.
#
# Opinionated layout:
#   /app      Drupal application root
#   /app/web  Drupal public docroot
#
# Public files are never baked into the application image.
# The app image only carries the symlink:
#   /app/web/files -> /mnt/files/public

ARG BUILDER_IMAGE=alchatti/drupal:builder
ARG RUNTIME_IMAGE=alchatti/drupal:fpm-apache

# ==========================
# 1) Builder Stage
# ==========================
FROM ${BUILDER_IMAGE} AS builder

COPY ./app ./

RUN set -eux; \
    composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist; \
    rm -rf /app/web/files; \
    ln -sfn /mnt/files/public /app/web/files


# ==========================
# 2) Runtime Stage
# ==========================
FROM ${RUNTIME_IMAGE}

COPY --from=builder --chown=www-data:www-data /app/ /app/
