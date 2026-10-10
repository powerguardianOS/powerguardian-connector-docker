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
COPY nut/ /app/nut-defaults/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
    && chmod 640 /app/nut-defaults/upsd.users /app/nut-defaults/upsmon.conf \
    # Overwrite apt-generated NUT configs with our defaults so the named
    # volume is seeded correctly on first Docker run (apt sets MODE=none).
    && cp /app/nut-defaults/nut.conf     /etc/nut/nut.conf \
    && cp /app/nut-defaults/ups.conf     /etc/nut/ups.conf \
    && cp /app/nut-defaults/upsd.conf    /etc/nut/upsd.conf \
    && cp /app/nut-defaults/upsd.users   /etc/nut/upsd.users \
    && cp /app/nut-defaults/upsmon.conf  /etc/nut/upsmon.conf \
    && chown root:nut /etc/nut/upsd.users /etc/nut/upsmon.conf \
    && chmod 640 /etc/nut/upsd.users /etc/nut/upsmon.conf

ENV PG_CONTROLLER_URL=""
ENV PG_AGENT_KEY=""
ENV PG_WATCHTOWER_URL=""
ENV PG_WATCHTOWER_TOKEN=""

EXPOSE 8090

VOLUME /data

ENTRYPOINT ["/entrypoint.sh"]
