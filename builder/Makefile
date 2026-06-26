# ============================================
# Docker Build Utility for Composer + NodeJS
# ============================================

.DEFAULT_GOAL := help

# Variables (overridable)
PHP_VERSION ?= 8.3
NODE_VERSION ?= 24
OS_VERSION ?= trixie

IMAGE_NAME ?= alchatti/php-builder
IMAGE_TAG ?= p$(PHP_VERSION)-n$(NODE_VERSION)-$(OS_VERSION)

TIMESTAMP := $(shell date +'%Y%m%d')
IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: build run check help

## 🏗️ Build the Docker image
build:
	@echo "🛠️  Building Docker image: $(IMAGE)"
	docker build \
		--build-arg OS=$(OS_VERSION) \
		--build-arg PHP=$(PHP_VERSION) \
		--build-arg NODE=$(NODE_VERSION) \
		--build-arg CREATE_DATE="$(TIMESTAMP)" \
        --build-arg VERSION='MAKE' \
		--no-cache \
		-t $(IMAGE_NAME):latest \
		-t $(IMAGE) .

## 🚀 Run the container interactively
run:
	@echo "🚀 Starting $(IMAGE)..."
	docker run --rm -it \
	-v ../example/app:/app \
	$(IMAGE) bash

## 🔍 Check installed versions inside the image
check:
	@echo "🔎 Checking versions in $(IMAGE)..."
	docker run --rm $(IMAGE) bash -c "\
		echo '✅ PHP Version:' && php --version && \
		echo && echo '✅ Composer Version:' && composer --version && \
		echo && echo '✅ Node Version:' && node --version && \
		echo && echo '✅ NPM Version:' && npm --version"

## ℹ️ Show available targets
help:
	@echo "Available targets:"
	@awk '/^## / {desc = substr($$0, 4); next} /^[a-zA-Z0-9_.-]+:/ {target = $$1; sub(/:.*/, "", target); if (desc != "") {printf "  %-12s %s\n", target, desc; desc = ""}}' $(MAKEFILE_LIST)
