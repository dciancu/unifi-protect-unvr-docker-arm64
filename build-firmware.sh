#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

docker build -f firmware-base.Dockerfile -t unvr-firmware-base .
docker build -f firmware.Dockerfile --no-cache -t unvr-firmware .
if [ -f firmware/version ]; then
    rm -r firmware/*
fi
docker build -f firmware-copy.Dockerfile --output firmware .
