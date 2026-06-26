# Drupal files facilitator image.
#
# Purpose:
#   - Initialize a /mnt/files named volume with the expected Drupal folder structure.
#   - Seed files copied into the image at build time.
#   - Create or restore tar.gz archives for migration/backup workflows.
#
# Build example:
#   docker build -f facilitator/Dockerfile -t alchatti/drupal:files-facilitator .
#
# App-specific child image example:
#   FROM alchatti/drupal:files-facilitator
#   COPY --chown=www-data:www-data files/public/ /payload/public/
#   COPY --chown=www-data:www-data files/private/ /payload/private/
#   COPY --chown=www-data:www-data files/config/sync/ /payload/config/sync/

ARG OS=bookworm

FROM debian:${OS}-slim

LABEL org.opencontainers.image.title="Drupal Files Facilitator" \
  org.opencontainers.image.description="Initializes, seeds, archives, and restores a Drupal /mnt/files named volume" \
  org.opencontainers.image.source="https://github.com/alchatti/docker-drupal"

ENV FILES_DIR=/mnt/files \
  PAYLOAD_DIR=/payload \
  ARCHIVE_DIR=/archive \
  FACILITATOR_ACTION=seed \
  CLEAR_TARGET=0 \
  ARCHIVE_NAME=drupal-files.tar.gz

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    coreutils \
    findutils \
    tar \
    gzip; \
  rm -rf /var/lib/apt/lists/*; \
  mkdir -p \
    /mnt/files/public \
    /mnt/files/private \
    /mnt/files/tmp \
    /mnt/files/config/sync \
    /payload \
    /archive; \
  chown -R www-data:www-data /mnt/files /payload /archive

COPY --chown=www-data:www-data --chmod=755 facilitator/files-facilitator.sh /usr/local/bin/files-facilitator.sh

WORKDIR /payload

USER www-data

ENTRYPOINT ["files-facilitator.sh"]
CMD ["seed"]
