#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

# Pin to UniFi OS 4.1.9 (only on CI build)
# https://github.com/dciancu/unifi-protect-unvr-docker-arm64/issues/23
if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" != 'test' ]]; then
    FW_URL='https://fw-download.ubnt.com/data/unifi-nvr/8972-UNVR-4.1.9-0caf6874-2af6-441e-abd6-cce9f015757e.bin'
fi

docker build -f firmware-base.Dockerfile -t unvr-firmware-base --pull .
docker build -f firmware.Dockerfile --no-cache -t unvr-firmware \
    --build-arg "FW_URL=${FW_URL:-}" --build-arg "ALL_DEBS=${ALL_DEBS:-}" .
if [ -f firmware/version ]; then
    rm -r firmware/*
fi
docker build -f firmware-copy.Dockerfile --output firmware .
