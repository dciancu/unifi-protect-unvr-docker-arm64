#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKERHUB_IMAGE:-unvr}"

if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'test' ]]; then
    docker build -f protect.Dockerfile --build-arg UNVR_STABLE=1 -t "${image_name}:test-stable" --pull .
    docker build -f protect.Dockerfile -t "${image_name}:test-edge" .
else
    version="$(tr -d '\n' < firmware/version)"
    docker build -f protect.Dockerfile --build-arg UNVR_STABLE=1 -t "${image_name}:stable" --pull .
    docker tag "${image_name}:stable" "${image_name}:${version}"
    docker build -f protect.Dockerfile -t "${image_name}:edge" .
fi
