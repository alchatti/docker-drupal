# ==========================
# 1) Builder Stage
# ==========================
FROM alchatti/drupal:builder AS builder

WORKDIR /app

# Copy the Drupal application source into the builder image.
# The application is expected to use /app/web as the public docroot.
COPY ./app/ ./

RUN set -eux; \
  composer install --no-dev --optimize-autoloader --no-interaction; \
  test -f /app/web/index.php; \
  mkdir -p /mnt/files/public; \
  if [ -L /app/web/files ]; then \
    rm -f /app/web/files; \
  elif [ -d /app/web/files ]; then \
    if [ -n "$(find /app/web/files -mindepth 1 -maxdepth 1 -print -quit)" ]; then \
      echo "ERROR: /app/web/files must be empty during image build. Public files are not part of the application image." >&2; \
      exit 1; \
    fi; \
    rmdir /app/web/files; \
  elif [ -e /app/web/files ]; then \
    echo "ERROR: /app/web/files exists but is not a directory or symlink." >&2; \
    exit 1; \
  fi; \
  ln -sfn /mnt/files/public /app/web/files; \
  # Optional cleanup if your builder image provides cleanup-build.
  if command -v cleanup-build >/dev/null 2>&1; then cleanup-build; fi

# ==========================
# 2) Runtime Stage
# ==========================
FROM alchatti/drupal:apache-fpm

WORKDIR /app

COPY --from=builder --chown=www-data:www-data /app/ /app/

# Keep the external files mount path present for non-volume/local smoke tests.
# When /mnt/files is mounted as a Docker volume, the facilitator image is
# responsible for creating the real mounted folder structure.
RUN set -eux; \
  mkdir -p /mnt/files/public /mnt/files/private /mnt/files/tmp /mnt/files/config/sync; \
  chown -R www-data:www-data /app /mnt/files
