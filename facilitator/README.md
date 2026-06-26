# Drupal Files Facilitator

The facilitator image initializes and manages the Drupal files volume mounted at `/mnt/files`.

It is intended to be run as a one-shot container before or alongside the Drupal app container.

## Folder structure

The facilitator creates:

```text
/mnt/files/public
/mnt/files/private
/mnt/files/tmp
/mnt/files/config/sync
```

The Drupal application image should already contain:

```text
/app/web/files -> /mnt/files/public
```

## Build a site-specific facilitator

```dockerfile
FROM alchatti/drupal:files-facilitator

COPY files/public/ /payload/public/
COPY files/private/ /payload/private/
COPY files/config/sync/ /payload/config/sync/
```

## Run examples

Initialize only:

```bash
docker run --rm -v drupal-files:/mnt/files my-files-facilitator init
```

Seed payload:

```bash
docker run --rm -v drupal-files:/mnt/files my-files-facilitator seed
```

Create archive:

```bash
docker run --rm \
  -v drupal-files:/mnt/files \
  -v "$PWD/archive:/archive" \
  my-files-facilitator archive
```

Restore archive:

```bash
docker run --rm \
  -v drupal-files:/mnt/files \
  -v "$PWD/archive:/archive" \
  -e CLEAR_TARGET=1 \
  my-files-facilitator restore /archive/drupal-files.tar.gz
```
