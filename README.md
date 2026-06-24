# docker-drupal

Opinionated Docker images for building and running Drupal applications with PHP, Composer, Node.js, Apache, PHP-FPM, and optional s6-overlay service supervision.

This repository supports a repeatable Drupal container workflow across local development, CI/CD, testing, UAT, and production-style runtime images.

## What this repository provides

- Drupal-ready PHP runtime images.
- Apache `mod_php` runtime variant.
- Apache + PHP-FPM runtime variant supervised by `s6-overlay`.
- Builder image with PHP, Composer, and Node.js.
- Shared shell scripts for installing PHP extensions, runtime dependencies, Apache/PHP configuration, s6 service generation, Drupal layout helpers, health checks, and image verification.
- GitHub Actions matrix builds for multiple PHP versions, OS versions, and image variants.
- Optional local image testing before pushing.
- Multi-platform builds for `linux/amd64` and `linux/arm64`.
- Environment-driven PHP configuration that can be overridden at container runtime.
- Branch-aware image tagging for non-main builds.
- Support for Docker SBOM and provenance attestations.

## Repository layout

```text
.
├── .github/workflows/
│   ├── build-and-push.yml
│   └── matrix-generator.yml
├── apache/
│   └── Dockerfile
├── apache-fpm/
│   └── Dockerfile
├── builder/
│   ├── Dockerfile
│   ├── cleanup-build.php
│   └── cleanup.json
├── serversideup-apache-fpm/
│   └── Dockerfile
├── scripts/
│   ├── _drupal-layout.sh
│   ├── configure-drupal-runtime.sh
│   ├── docker-entrypoint-apache.sh
│   ├── generate-s6-services.sh
│   ├── healthcheck.sh
│   ├── install-php-dependencies.sh
│   ├── install-runtimes.sh
│   ├── verify-apache-php.sh
│   └── verify-builder.sh
├── app/
├── cron/
├── example/
└── README.md
```

## Image variants

### `builder`

A non-root PHP builder image intended for Composer, npm, and Drupal build operations.

Typical contents:

- PHP CLI
- Composer
- Node.js
- npm
- Drupal-required PHP extensions
- `cleanup-build` helper
- `verify-builder.sh`

Default user:

```text
www-data
```

Typical use:

```bash
docker run --rm -it \
  -v "$PWD:/app" \
  alchatti/drupal:builder \
  bash
```

Run verification:

```bash
docker run --rm alchatti/drupal:builder verify-builder.sh
```

### `apache`

Apache `mod_php` runtime image based on the official `php:<version>-apache-<os>` image.

Characteristics:

- Apache prefork MPM
- PHP loaded as Apache module
- Non-root runtime user
- Environment-driven PHP configuration
- Runtime Apache tuning through the shared entrypoint
- Suitable for simpler Apache/PHP runtime deployments

Default command:

```text
apache2-foreground
```

### `apache-fpm`

Apache + PHP-FPM runtime image based on the official `php:<version>-fpm-<os>` image.

Characteristics:

- Apache event MPM
- PHP-FPM over Unix socket
- s6-overlay v3 service supervision
- Apache depends on PHP-FPM
- Non-root runtime user
- Environment-driven PHP configuration
- Runtime memory and worker tuning through the shared entrypoint

Default command:

```text
/init
```

Services are generated under:

```text
/etc/s6-overlay/s6-rc.d
```

This means the image uses the s6-overlay v3 `s6-rc` service layout, not the legacy `/etc/services.d` layout.

### `serversideup-apache-fpm`

Alternative runtime image based on `serversideup/php:<version>-fpm-apache-<os>`.

This variant is useful when you want to compare or use the ServersideUp PHP base image while still applying this repository’s Drupal runtime dependency and verification approach.

## Image tags

The GitHub Actions matrix generator builds image tags using:

```text
<php-version>-<variant>-<os>
```

Examples:

```text
alchatti/drupal:8.4-apache-trixie
alchatti/drupal:8.4-apache-fpm-trixie
alchatti/drupal:8.4-builder-trixie
```

For the latest PHP and OS values in the matrix, a shorter variant tag is also generated:

```text
alchatti/drupal:apache
alchatti/drupal:apache-fpm
alchatti/drupal:builder
```

### Branch tags

On `main`, clean production-style tags are used:

```text
alchatti/drupal:8.4-apache-trixie
alchatti/drupal:apache
```

On non-main branches, the branch name is added as a prefix:

```text
alchatti/drupal:dev-8.4-apache-trixie
alchatti/drupal:dev-apache
```

For branch names with slashes or special characters, the branch name is sanitized.

Example:

```text
feature/test-cache
```

becomes:

```text
feature-test-cache-
```

resulting in tags like:

```text
alchatti/drupal:feature-test-cache-8.4-apache-trixie
alchatti/drupal:feature-test-cache-apache
```

## Runtime configuration

The runtime images use Dockerfile `ENV` defaults and PHP `.ini` placeholders.

The build-time script writes PHP configuration to:

```text
/usr/local/etc/php/conf.d/docker-php-drupal-recommended.ini
```

The PHP ini file uses environment placeholders such as:

```ini
memory_limit=${PHP_MEMORY_LIMIT}
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}
post_max_size=${PHP_POST_MAX_SIZE}
max_execution_time=${PHP_MAX_EXECUTION_TIME}
opcache.memory_consumption=${PHP_OPCACHE_MEMORY_CONSUMPTION}
```

This allows runtime overrides without rebuilding the image.

## Important environment variables

### Application paths

| Variable | Default | Description |
|---|---:|---|
| `APP_ROOT` | `/app` | Drupal application root |
| `DOC_ROOT` | *(empty — resolved to `APP_ROOT/DRUPAL_PUBLIC_DIR` at runtime)* | Apache document root |
| `DRUPAL_PUBLIC_DIR` | `web` | Drupal web subdirectory (`web` or `docroot`) |
| `PUBLIC_ROOT` | `/var/www/html` | Apache `DocumentRoot` symlink target |
| `CONFIG_ROOT` | `/_config` | Runtime configuration directory |
| `APACHE_CONFIG_DIR` | `/_config/apache` | Apache config include directory |
| `FILES_DIR` | `/mnt/files` | External files mount path |
| `DRUPAL_SUBDIR` | empty | Optional Apache alias path |
| `APACHE_PORT` | `8080` | Apache listen port |
| `TZ` | `Asia/Dubai` | PHP timezone |

### PHP runtime settings

| Variable | Default |
|---|---:|
| `PHP_MEMORY_LIMIT` | `512M` |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `512` |
| `PHP_UPLOAD_MAX_FILESIZE` | `64M` |
| `PHP_POST_MAX_SIZE` | `64M` |
| `PHP_MAX_EXECUTION_TIME` | `120` |
| `PHP_MAX_INPUT_VARS` | `4000` |
| `PHP_OUTPUT_BUFFERING` | `true` |
| `PHP_REALPATH_CACHE_SIZE` | `4096K` |
| `PHP_REALPATH_CACHE_TTL` | `600` |
| `PHP_OPCACHE_ENABLE` | `1` |
| `PHP_OPCACHE_ENABLE_CLI` | `1` |
| `PHP_OPCACHE_INTERNED_STRINGS_BUFFER` | `16` |
| `PHP_OPCACHE_MAX_ACCEL_FILES` | `50000` |
| `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `0` |
| `PHP_OPCACHE_REVALIDATE_FREQ` | `60` |

### Auto-tuning controls

The Apache runtime entrypoint calculates memory and worker settings when the web server starts.

| Variable | Default | Description |
|---|---:|---|
| `DEFAULT_MEMORY_LIMIT_MB` | `1024` | Used when no container memory limit is detected |
| `USE_HOST_MEMORY_WHEN_UNLIMITED` | `0` | Whether to use host memory when cgroup memory is unlimited |
| `RESERVED_MEMORY_MIN_MB` | `128` | Minimum reserved memory |
| `RESERVED_MEMORY_FRACTION` | `10` | Reserve `TOTAL_MB / 10` |
| `PHP_MEMORY_LIMIT_MIN_MB` | `128` | Minimum calculated PHP memory limit |
| `PHP_MEMORY_LIMIT_MAX_MB` | `768` | Maximum calculated PHP memory limit |
| `OPCACHE_MIN_MB` | `96` | Minimum calculated OPcache memory |
| `OPCACHE_MAX_MB` | `256` | Maximum calculated OPcache memory |
| `AVG_PHP_THREAD_MB` | `120` | Estimated memory per PHP worker/thread |
| `HEADROOM_MB` | `64` | Extra runtime headroom |
| `MIN_PHP_THREADS` | `2` | Minimum PHP workers |
| `MAX_PHP_THREADS_CAP` | `256` | Maximum PHP workers |
| `START_WORKERS` | `2` | Initial Apache/FPM workers |
| `MIN_SPARE_WORKERS` | `2` | Minimum spare workers |
| `MAX_SPARE_WORKERS` | `10` | Maximum spare workers |
| `MAX_REQUESTS_PER_CHILD` | `5000` | Recycle worker after this many requests |
| `APACHE_WORKERS_MULTIPLIER` | `4` | Apache workers relative to PHP workers |
| `APACHE_MAX_REQUEST_WORKERS_CAP` | `400` | Maximum Apache workers |

## Memory behavior

For normal Apache startup, the entrypoint calculates memory values and exports:

```text
PHP_MEMORY_LIMIT
PHP_OPCACHE_MEMORY_CONSUMPTION
```

For one-off CLI commands such as Drush, the entrypoint bypasses web initialization and the Dockerfile defaults remain active.

Example:

```bash
docker run --rm alchatti/drupal:apache-fpm drush status
```

This means Drush has safe default PHP values without requiring Apache/FPM initialization.

## Runtime overrides

You can override PHP values at runtime without rebuilding the image.

Example:

```bash
docker run --rm -it \
  -e PHP_UPLOAD_MAX_FILESIZE=128M \
  -e PHP_POST_MAX_SIZE=129M \
  -e PHP_MAX_EXECUTION_TIME=180 \
  alchatti/drupal:apache
```

When increasing upload size, keep:

```text
PHP_POST_MAX_SIZE >= PHP_UPLOAD_MAX_FILESIZE
```

For Docker Compose:

```yaml
services:
  drupal:
    image: alchatti/drupal:apache-fpm
    environment:
      PHP_UPLOAD_MAX_FILESIZE: 128M
      PHP_POST_MAX_SIZE: 129M
      PHP_MAX_EXECUTION_TIME: "180"
```

## Drupal subdirectory alias

Set `DRUPAL_SUBDIR` to expose Drupal under a subdirectory path.

Example:

```bash
docker run --rm -p 8080:8080 \
  -e DRUPAL_SUBDIR=/test-site \
  alchatti/drupal:apache
```

The site becomes available at:

```text
http://localhost:8080/test-site
```

The entrypoint normalizes leading and trailing slashes.

These are equivalent:

```text
test-site
/test-site
/test-site/
```

## File mounts

The images create and prepare:

```text
/mnt/files/public
/mnt/files/private
/mnt/files/tmp
/mnt/files/config/sync
```

Recommended volume example:

```yaml
services:
  drupal:
    image: alchatti/drupal:apache-fpm
    volumes:
      - ./web:/var/www/html
      - drupal-files:/mnt/files

volumes:
  drupal-files:
```

## Cron

The `cron/` directory contains helper scripts for running Drush cron as a one-off container command.

Docker Compose example:

```yaml
services:
  web:
    image: alchatti/drupal:apache-fpm
    volumes:
      - files:/mnt/files

  cron:
    image: alchatti/drupal:apache-fpm
    profiles:
      - cron
    volumes:
      - files:/mnt/files
    command: drush --root=/app/web cron

volumes:
  files:
```

Manual run:

```bash
docker compose run --rm cron
```

For Kubernetes, use a `CronJob` resource. If the Drupal files volume is also mounted by web pods, ensure the storage class supports your access pattern (RWX for multi-pod scenarios).

## Healthcheck

Runtime images use:

```text
healthcheck.sh
```

Typical Dockerfile healthcheck:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["healthcheck.sh"]
```

The healthcheck should remain lightweight and confirm the container is serving correctly.

## Verification scripts

### Builder verification

```bash
verify-builder.sh
```

Validates builder tools such as:

- Composer
- Node.js
- npm
- Drupal project creation

Example:

```bash
docker run --rm alchatti/drupal:builder verify-builder.sh
```

### Apache/PHP verification

```bash
verify-apache-php.sh
```

Validates:

- Apache can serve a generated PHP file
- PHP runtime values are applied
- upload size overrides work
- `post_max_size` override works
- `max_execution_time` override works
- memory values are printed for review

Example:

```bash
docker run -d \
  --name apache-php-test \
  -e DRUPAL_SUBDIR=/test-site \
  -e PHP_UPLOAD_MAX_FILESIZE=128M \
  -e PHP_POST_MAX_SIZE=129M \
  -e PHP_MAX_EXECUTION_TIME=180 \
  alchatti/drupal:apache-fpm

docker exec apache-php-test verify-apache-php.sh
docker rm -f apache-php-test
```

A temporary test file is created under the document root and removed automatically after the test.

## Build locally

### Apache mod_php

```bash
docker build \
  --build-arg PHP=8.4 \
  --build-arg OS=trixie \
  -t alchatti/drupal:8.4-apache-trixie \
  -f apache/Dockerfile .
```

### Apache + PHP-FPM + s6-overlay

```bash
docker build \
  --build-arg PHP=8.4 \
  --build-arg OS=trixie \
  -t alchatti/drupal:8.4-apache-fpm-trixie \
  -f apache-fpm/Dockerfile .
```

### Builder

```bash
docker build \
  --build-arg PHP=8.4 \
  --build-arg OS=trixie \
  --build-arg NODE_VERSION=24 \
  -t alchatti/drupal:8.4-builder-trixie \
  -f builder/Dockerfile .
```

## Run locally

### Apache mod_php

```bash
docker run --rm -p 8080:8080 \
  alchatti/drupal:apache
```

### Apache + PHP-FPM

```bash
docker run --rm -p 8080:8080 \
  alchatti/drupal:apache-fpm
```

Open:

```text
http://localhost:8080
```

### Run a one-off command

```bash
docker run --rm alchatti/drupal:apache-fpm php -v
```

```bash
docker run --rm alchatti/drupal:apache-fpm drush status
```

The entrypoint detects one-off commands and bypasses Apache/FPM initialization.

## GitHub Actions workflow

The main workflow uses:

```text
.github/workflows/build-and-push.yml
```

It calls:

```text
.github/workflows/matrix-generator.yml
```

The matrix generator accepts:

```yaml
php_versions: '["8.4"]'
os_versions: '["trixie"]'
blueprints: |
  {
    "builder": {
      "build_args": ["NODE=24"],
      "test_command": "docker run --rm \"$IMAGE\" verify-builder.sh"
    },
    "serversideup-apache-fpm": {},
    "apache": {
      "test_command": "..."
    },
    "apache-fpm": {
      "test_command": "..."
    }
  }
```

The generated matrix includes:

- context folder
- Dockerfile target
- image variant
- build arguments
- test command
- local test image tag
- final registry tags

## Optional image testing before push

The reusable build workflow can build a local single-platform image with:

```text
load: true
```

Then run the configured test command before the final multi-platform push.

Only after the test passes does the workflow proceed to the real multi-platform build and push.

## SBOM and provenance

The reusable Docker build workflow supports:

```yaml
sbom: true
provenance: mode=max
```

SBOM and provenance attestations require pushing to a registry.

Make sure the Docker Hub token used by GitHub Actions has write access to the target namespace and repository.

## Docker Hub authentication

GitHub Actions requires these secrets:

```text
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN
```

`DOCKERHUB_TOKEN` should be a Docker Hub personal access token with read/write access to the target repository.

A token with insufficient scope may fail with:

```text
401 Unauthorized: access token has insufficient scopes
```

## Non-root runtime

Runtime images use:

```text
www-data
```

The image prepares writable paths for:

```text
/app
/var/www
/_config
/mnt/files
/var/run/apache2
/var/lock/apache2
/var/log/apache2
/var/run/php
/etc/apache2
```

The builder image also defaults to `www-data` and prepares writable Composer/npm cache locations.

## s6-overlay notes

The `apache-fpm` image uses s6-overlay v3 service definitions generated under:

```text
/etc/s6-overlay/s6-rc.d
```

The generator creates:

```text
php-fpm
apache
user/contents.d/php-fpm
user/contents.d/apache
apache/dependencies.d/php-fpm
```

Apache depends on PHP-FPM.

Seeing this message is normal:

```text
s6-rc: info: service legacy-services: starting
```

It does not mean your services are legacy. It is part of the s6-overlay compatibility layer. The repository services are generated under the modern `s6-rc.d` path.

## Common troubleshooting

### `s6-overlay-suexec: fatal: can only run as pid 1`

This means `/init` was started outside the normal container PID 1 startup path.

Common causes:

- Running `/init` during a Dockerfile `RUN` step.
- Accidentally replacing `configure-drupal-runtime.sh` with entrypoint content.
- Running `/init` through `docker exec`.

`configure-drupal-runtime.sh` must never start `/init`, Apache, PHP-FPM, or call `exec "$@"`.

### First Apache-FPM test returns `503`

A first attempt may return `503` while PHP-FPM is still becoming ready.

If the retry passes, the image is healthy.

### Runtime upload override does not apply

Check that the PHP ini file contains placeholders, not build-time expanded values:

```ini
upload_max_filesize=${PHP_UPLOAD_MAX_FILESIZE}
post_max_size=${PHP_POST_MAX_SIZE}
```

Also confirm PHP-FPM has:

```ini
clear_env = no
```

### Branch images are overwriting main tags

Branch tags should be prefixed on non-main branches.

Example:

```text
feature-test-cache-apache
feature-test-cache-8.4-apache-trixie
```

Main should keep clean tags:

```text
apache
8.4-apache-trixie
```

## License

This repository is licensed under the MIT License.
