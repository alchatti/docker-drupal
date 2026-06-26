# Drupal files facilitator image.
#
# Purpose:
#   - Initialize a /mnt/files volume with the expected Drupal folder structure.
#   - Seed files copied into the image at build time.
#   - Create or restore tar.gz archives for migration/backup workflows.
#
# Build example:
#   docker build -f facilitator/Dockerfile -t my-drupal-files-facilitator .
#
# App-specific child image example:
#   FROM alchatti/drupal:files-facilitator
#   COPY files/public/ /payload/public/
#   COPY files/private/ /payload/private/
#   COPY files/config/sync/ /payload/config/sync/

FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="Drupal Files Facilitator" \
  org.opencontainers.image.description="Initializes, seeds, archives, and restores a Drupal /mnt/files volume" \
  org.opencontainers.image.source="https://github.com/alchatti/docker-drupal"

ENV FILES_DIR=/mnt/files \
  PAYLOAD_DIR=/payload \
  ARCHIVE_DIR=/archive \
  FACILITATOR_ACTION=seed \
  CLEAR_TARGET=0 \
  FIX_OWNERSHIP=1 \
  FILES_UID=33 \
  FILES_GID=33 \
  ARCHIVE_NAME=drupal-files.tar.gz

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    coreutils \
    findutils \
    tar; \
  rm -rf /var/lib/apt/lists/*; \
  mkdir -p /mnt/files /payload /archive

COPY --chmod=755 facilitator/files-facilitator.sh /usr/local/bin/files-facilitator.sh

WORKDIR /payload

ENTRYPOINT ["files-facilitator.sh"]
CMD ["seed"]
