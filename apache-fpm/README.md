# Makefile Usage Guide

This Makefile is used to build, verify, run, and test the Drupal PHP-FPM Apache Docker image locally.

## Default Values

The Makefile uses these default values:

```makefile
PHP_VERSION ?= 8.4
IMAGE       ?= alchatti/drupal-fpm-apache:latest
NAME        ?= drupal-fpm
```

You can override any value when running a command.

Example:

```bash
make build IMAGE=local/drupal-fpm-apache:test
```

---

## Build the Image

```bash
make build
```

This builds the Docker image using the configured PHP version and image name.

Equivalent Docker command:

```bash
docker build --build-arg PHP=8.4 -t alchatti/drupal-fpm-apache:latest .
```

---

## Verify the Image

```bash
make check
```

This builds the image and runs the Drupal runtime requirement checker inside the image.

By default, the check expects:

```makefile
DRUPAL_DB_DRIVER = mysql
REQUIRE_REDIS    = 1
REQUIRE_IMAGICK  = 1
REQUIRE_BCMATH   = 1
```

Use this when you want to confirm the image has the required PHP extensions and production runtime dependencies.

### Minimal Check

If Redis, Imagick, or BCMath are not required:

```bash
make check REQUIRE_REDIS=0 REQUIRE_IMAGICK=0 REQUIRE_BCMATH=0
```

### PostgreSQL Check

```bash
make check DRUPAL_DB_DRIVER=pgsql
```

### SQLite Check

```bash
make check DRUPAL_DB_DRIVER=sqlite
```

---

## Run the Container

```bash
make run
```

This starts the container locally using the configured container name.

The site will be available at:

```text
http://localhost:8080
```

---

## Check PHP Modules

```bash
make check-mods
```

This checks the loaded PHP modules inside the running container.

Run `make run` first before using this command.

---

## Open a Shell

```bash
make shell
```

This opens a shell inside the running container.

Run `make run` first before using this command.

---

## Stop the Container

```bash
make stop
```

This stops the running container.

---

## Remove the Local Image

```bash
make clean
```

This removes the local Docker image defined by the `IMAGE` variable.

---

## Common Local Workflow

```bash
make check
make run
make check-mods
make shell
make stop
```

For a minimal extension check:

```bash
make check REQUIRE_REDIS=0 REQUIRE_IMAGICK=0 REQUIRE_BCMATH=0
```
 
