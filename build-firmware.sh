#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

docker build -t unvr-firmware-base --pull - < firmware-base.Dockerfile
docker build --no-cache -t unvr-firmware \
    --build-arg "FW_URL=${FW_URL:-}" --build-arg "ALL_DEBS=${ALL_DEBS:-}" - < firmware.Dockerfile
if [ -f firmware/version ]; then
    rm -r firmware/*
fi
docker build --output firmware - < firmware-copy.Dockerfile
