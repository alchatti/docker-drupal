# Makefile for crp-drupal
# Usage:
#   make build
#   make run
#   make check-mods
#   make stop

IMAGE ?= drupal-fpm-apache:latest
NAME  ?= drupal-fpm

.PHONY: build run check-mods stop

build:
	docker build -t $(IMAGE) .

# Run with a fixed name so we can exec into it.
# Memory limit is optional; defaults to 2GB.
run:
	docker run --rm --name $(NAME) \
		-p 8080:80 \
		$(IMAGE)

# Check loaded PHP modules inside the running container
check-mods:
	docker exec -it $(NAME) php -m | grep -Ei 'gd|imagick|pdo_mysql|mysqli|pdo_pgsql|pgsql|pdo_sqlite|sqlite3|mbstring|curl'

# Stop the running container (if needed)
stop:
	-@docker stop $(NAME) >/dev/null 2>&1 || true 
