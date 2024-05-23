#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKERHUB_IMAGE:-unvr}"
version="$(tr -d '\n' < firmware/version)"
docker build -f protect.Dockerfile --build-arg UNVR_STABLE=1 -t "${image_name}:stable" .
docker tag "${image_name}:stable" "${image_name}:${version}"
docker build -f protect.Dockerfile -t "${image_name}:edge" .
