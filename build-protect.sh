#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

docker build --build-arg UNVR_STABLE=1 -t unvr:stable .
docker build -t unvr:latest .
