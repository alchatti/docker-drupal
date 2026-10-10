# Makefile for crp-drupal
# Usage:
#   make build
#   make run
#   make check
#   make stop

IMAGE ?= drupal-testflight:latest
NAME  ?= drupal-testflight

.PHONY: build run check stop

build:
	docker build -t $(IMAGE) .

# Run with Docker compose
run:
	docker compose up

# Check loaded PHP modules inside the running container
check:
	docker exec -it $(NAME) php -m | grep -Ei 'gd|imagick|pdo_mysql|mysqli|pdo_pgsql|pgsql|pdo_sqlite|sqlite3|mbstring|curl'

# Stop
stop:
	docker compose down
