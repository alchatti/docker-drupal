# ============================================
# Docker Build Utility for Composer + NodeJS
# ============================================

.DEFAULT_GOAL := help

# Variables (overridable)
PHP ?= 8.4
OS ?= trixie
# Subsite Alias
SITE ?= example

IMAGE_NAME ?= local/drupal-apache
IMAGE_TAG ?= p$(PHP)-$(OS)
CONTAINER_NAME ?= drupal-apache

TIMESTAMP := $(shell date +'%Y%m%d')
IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: build run test help

## 🏗️ Build the Docker image
build:
	@echo "🛠️  Building Docker image: $(IMAGE)"
	docker build \
		-f Dockerfile \
		--build-arg OS=$(OS) \
		--build-arg PHP=$(PHP) \
		--build-arg CREATE_DATE="$(TIMESTAMP)" \
		--no-cache \
		-t $(IMAGE) ..

## 🚀 Run the container with port 8080 | site alias `SITE=example`
run:
	@echo "🚀 Starting $(IMAGE)..."
	docker run --rm --name $(CONTAINER_NAME) \
	-e DRUPAL_SUBDIR="$(SITE)" \
	-v ../app:/var/www/html/web \
	-p 8080:8080 \
	$(IMAGE)

## 🔍 Run test | optional `make test SITE=example`
test:
	@echo "🔍 Running test script in $(IMAGE)..."
	docker run -d --name $(CONTAINER_NAME)-test \
	-e DRUPAL_SUBDIR="$(SITE)" \
	-p 8080:8080 \
	"$(IMAGE)" \
	&& sleep 5 \
	&& docker exec $(CONTAINER_NAME)-test verify-apache-php.sh \
	&& docker rm -f $(CONTAINER_NAME)-test

## ℹ️ Show available targets
help:
	@echo "Available targets:"
	@awk '/^## / {desc = substr($$0, 4); next} /^[a-zA-Z0-9_.-]+:/ {target = $$1; sub(/:.*/, "", target); if (desc != "") {printf "  %-12s %s\n", target, desc; desc = ""}}' $(MAKEFILE_LIST)
