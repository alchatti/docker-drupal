# ============================================
# Docker Build Utility for Composer + NodeJS
# ============================================

.DEFAULT_GOAL := help

# Variables (overridable)
PHP_VERSION ?= 8.3
NODE_VERSION ?= 24
OS_VERSION ?= trixie

IMAGE_NAME ?= php-builder
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
        --build-arg RELEASE='MAKE'
		--no-cache \
		-t $(IMAGE) .

## 🚀 Run the container interactively
run:
	@echo "🚀 Starting $(IMAGE)..."
	docker run --rm -it $(IMAGE) bash

## 🔍 Check installed versions inside the image
check:
	@echo "🔎 Checking versions in $(IMAGE)..."
	docker run --rm $(IMAGE) bash -c "\
		echo '✅ PHP Version:' && php --version && \
		echo && echo '✅ Composer Version:' && composer --version && \
		echo && echo '✅ Node Version:' && node --version && \
		echo && echo '✅ NPM Version:' && npm --version"

## 📘 Display help
help:
	@echo ""
	@echo "📘 Available Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  make %-10s %s\n", $$1, $$2}'
	@echo ""
