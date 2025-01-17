#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

image_name="${DOCKER_IMAGE:-dciancu/unifi-protect-unvr-docker-arm64}"

if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'test' ]]; then
    docker build -f protect.Dockerfile --build-arg UNVR_STABLE=1 -t "${image_name}:test-stable" --pull .
    docker build -f protect.Dockerfile -t "${image_name}:test-edge" .
else
    if [[ -n "${CIRCLE_BRANCH+x}" ]] && [[ "$CIRCLE_BRANCH" == 'build' ]]; then
        docker images | grep "$image_name" | tr -s ' ' | cut -d ' ' -f 2 \
            | xargs -I {} docker rmi -f "${image_name}:{}" || true
        docker buildx prune -f
    fi

    firmware_version="$(tr -d '\n' < firmware/version)"
    docker build -f protect.Dockerfile --build-arg UNVR_STABLE=1 -t "${image_name}:stable" --pull .
    docker tag "${image_name}:stable" "${image_name}:${firmware_version}"
    version="$(docker run --rm "${image_name}:stable" dpkg -s unifi-protect | grep '^Version:' | cut -d ' ' -f 2 | tr -d '\n')"
    docker tag "${image_name}:stable" "${image_name}:v${version}"
    docker tag "${image_name}:stable" "${image_name}:v$(cut -d '.' -f 1-2 <<< "$version")"
    docker tag "${image_name}:stable" "${image_name}:v$(cut -d '.' -f 1 <<< "$version")"

    docker build -f protect.Dockerfile -t "${image_name}:edge" .
    version="$(docker run --rm "${image_name}:edge" dpkg -s unifi-protect | grep '^Version:' | cut -d ' ' -f 2 | tr -d '\n')"
    docker tag "${image_name}:edge" "${image_name}:v${version}"
    docker tag "${image_name}:edge" "${image_name}:v$(cut -d '.' -f 1-2 <<< "$version")"
    docker tag "${image_name}:edge" "${image_name}:v$(cut -d '.' -f 1 <<< "$version")"
fi
