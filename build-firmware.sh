#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

opts=''
if [[ -n "${DOCKER_NO_CACHE+x}" ]]; then
    opts='--no-cache'
fi

docker build $opts -f firmware-base.Dockerfile -t unvr-firmware-base --pull .
docker build $opts -f firmware.Dockerfile --no-cache -t unvr-firmware \
    --build-arg "FW_URL=${FW_URL:-}" --build-arg "FW_EDGE=${FW_EDGE:-}" \
    --build-arg "FW_ALL_DEBS=${FW_ALL_DEBS:-}" --build-arg "FW_UNSTABLE=${FW_UNSTABLE:-}" .
if [ -f firmware/version ]; then
    rm -r firmware/*
fi
docker build -f firmware-copy.Dockerfile --output firmware .
