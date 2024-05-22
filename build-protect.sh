#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKERHUB_IMAGE:-unvr}"
version="$(tr -d '\n' < firmware-build/firmware/version)"
docker build --build-arg UNVR_STABLE=1 -t "${image_name}:stable" .
docker tag "${image_name}:stable" "${image_name}:${version}"
docker build -t "${image_name}:latest" .
