# ============================================
# Docker Build Utility for Composer + NodeJS
# ============================================

.DEFAULT_GOAL := help

# Variables (overridable)
PHP ?= 8.4
OS ?= trixie
# Subsite Alias
SITE ?= example
# Runtime Resource Controls
MEM ?= 2

IMAGE_NAME ?= local/drupal-apache-fpm
IMAGE_TAG ?= p$(PHP)-$(OS)
CONTAINER_NAME ?= drupal-apache-fpm

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
	--memory=$(MEM)g \
	-e DRUPAL_SUBDIR="$(SITE)" \
	-e PHP_UPLOAD_MAX_FILESIZE=100M \
	-e PHP_POST_MAX_SIZE=100M \
	-v ../app:/var/www/html/web \
	-p 8080:8080 \
	$(IMAGE)

## 🔍 Run test | optional `make test SITE=example`
test:
	@echo "🔍 Running external test for $(IMAGE)..."
	IMAGE="$(IMAGE)" DRUPAL_SUBDIR="$(SITE)" \
	bash test/test-apache-php.sh "$(IMAGE)"

## ℹ️ Show available targets
help:
	@echo "Available targets:"
	@awk '/^## / {desc = substr($$0, 4); next} /^[a-zA-Z0-9_.-]+:/ {target = $$1; sub(/:.*/, "", target); if (desc != "") {printf "  %-12s %s\n", target, desc; desc = ""}}' $(MAKEFILE_LIST)
