#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

echo "$DOCKER_PASS" | docker login -u "$DOCKER_USERNAME" --password-stdin

image_name="${DOCKER_IMAGE:-dciancu/unifi-protect-unvr-docker-arm64}"

if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'test' ]]; then
    docker push "${image_name}:test-stable"
    docker push "${image_name}:test-edge"
else
    docker rmi "${image_name}:test-stable" 2>/dev/null || true
    docker rmi "${image_name}:test-edge" 2>/dev/null || true
    docker push --all-tags "$image_name"
fi
