#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}/firmware-build"

docker build --no-cache --target firmware-build -t unvr-firmware .
docker build --output=firmware --target=firmware .
