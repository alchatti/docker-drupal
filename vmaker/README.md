# Drupal Files vmaker

The files vmaker is a small one-shot container used to initialize, seed, archive, or restore a Drupal `/mnt/files` named volume.

It runs as `www-data` and is designed for Docker named volumes, not bind mounts.

## Directory layout

```text
/mnt/files/public
/mnt/files/private
/mnt/files/tmp
/mnt/files/config/sync
```

The Drupal application image should contain this symlink:

```text
/app/web/files -> /mnt/files/public
```

## Build the base vmaker image

```bash
docker build -f vmaker/Dockerfile -t alchatti/drupal:files-vmaker .
```

## App-specific vmaker image

```dockerfile
FROM alchatti/drupal:files-vmaker

COPY --chown=www-data:www-data files/public/ /payload/public/
COPY --chown=www-data:www-data files/private/ /payload/private/
COPY --chown=www-data:www-data files/config/sync/ /payload/config/sync/
```

## Actions

```bash
docker run --rm -v drupal-files:/mnt/files alchatti/drupal:files-vmaker init

docker run --rm -v drupal-files:/mnt/files my-site-files-vmaker seed

docker run --rm \
  -v drupal-files:/mnt/files \
  -v drupal-archive:/archive \
  alchatti/drupal:files-vmaker archive

docker run --rm \
  -v drupal-files:/mnt/files \
  -v drupal-archive:/archive \
  -e CLEAR_TARGET=1 \
  alchatti/drupal:files-vmaker restore
```

## Environment variables

```text
FILES_DIR=/mnt/files
PAYLOAD_DIR=/payload
ARCHIVE_DIR=/archive
VMAKER_ACTION=seed
CLEAR_TARGET=0
ARCHIVE_NAME=drupal-files.tar.gz
```
