# syntax=docker/dockerfile:1
# PowerGuardian Connector OS — multi-platform Docker image
# Supported platforms: linux/arm/v7  linux/amd64  linux/arm64

# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM --platform=$BUILDPLATFORM golang:1.25-bookworm AS builder

ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /build
COPY connector-os/ .

RUN GOOS=linux \
    GOARCH=${TARGETARCH} \
    GOARM=${TARGETVARIANT#v} \
    CGO_ENABLED=0 \
    go build -tags docker -ldflags="-s -w" -o /pg-connector ./agent

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim

# nut-server includes: nut-scanner, upsdrvctl, upsd
# nut-client includes: upsc, upscmd, upsmon
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        nut \
        nut-server \
        nut-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/nut /var/run/nut /var/state/ups \
    && chown -R root:nut /etc/nut /var/run/nut /var/state/ups 2>/dev/null || true

WORKDIR /app
COPY --from=builder /pg-connector .
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV PG_CONTROLLER_URL=""
ENV PG_AGENT_KEY=""
ENV PG_WATCHTOWER_URL=""
ENV PG_WATCHTOWER_TOKEN=""

EXPOSE 8090

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
