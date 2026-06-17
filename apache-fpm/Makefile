# Makefile for crp-drupal
# Usage:
#   make build
#   make check
#   make run
#   make check-mods
#   make stop

PHP_VERSION ?= 8.4
IMAGE       ?= alchatti/drupal-fpm-apache:latest
NAME        ?= drupal-fpm

# Drupal image check settings
DRUPAL_DB_DRIVER ?= mysql
REQUIRE_REDIS    ?= 1
REQUIRE_IMAGICK  ?= 1
REQUIRE_BCMATH   ?= 1

.PHONY: build check run check-mods shell stop clean

build:
	docker build \
		--build-arg PHP=$(PHP_VERSION) \
		-t $(IMAGE) .

# Build the image and verify Drupal 11 runtime requirements.
check: build
	docker run --rm \
		-e DRUPAL_DB_DRIVER=$(DRUPAL_DB_DRIVER) \
		-e REQUIRE_REDIS=$(REQUIRE_REDIS) \
		-e REQUIRE_IMAGICK=$(REQUIRE_IMAGICK) \
		-e REQUIRE_BCMATH=$(REQUIRE_BCMATH) \
		$(IMAGE) \
		drupal-image-check

# Run with a fixed name so we can exec into it.
run:
	docker run --rm --name $(NAME) \
		-p 8080:80 \
		$(IMAGE)

# Check loaded PHP modules inside the running container.
check-mods:
	docker exec -it $(NAME) php -m | grep -Ei 'gd|imagick|redis|bcmath|pdo_mysql|mysqli|pdo_pgsql|pgsql|pdo_sqlite|sqlite3|mbstring|curl|intl|zip|opcache|xml|dom|simplexml'

# Open a shell inside the running container.
shell:
	docker exec -it $(NAME) sh

# Stop the running container.
stop:
	-@docker stop $(NAME) >/dev/null 2>&1 || true

# Remove local image.
clean:
	-@docker rmi $(IMAGE) >/dev/null 2>&1 || true 
