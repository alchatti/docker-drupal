ARG PHP='8.5'
ARG OS='bookworm'
ARG BASE_IMAGE="php:${PHP}-fpm-${OS}"

#! S6 Build
FROM ${BASE_IMAGE} AS s6-build

ARG S6_OVERLAY_VERSION="3.2.1.0"
ARG TARGETARCH

RUN set -eux; \
# --- s6-overlay install (map TARGETARCH -> s6 arch) ---
  case "$TARGETARCH" in \
  amd64) s6arch="x86_64" ;; \
  arm64) s6arch="aarch64" ;; \
  *) echo "Unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  curl -fsSL -o /tmp/s6-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
  curl -fsSL -o /tmp/s6-arch.tar.xz   "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${s6arch}.tar.xz"; \
  tar -C / -Jxpf /tmp/s6-noarch.tar.xz; \
  tar -C / -Jxpf /tmp/s6-arch.tar.xz;
