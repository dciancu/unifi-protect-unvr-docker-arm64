#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

opts=''
image_name="${DOCKER_IMAGE:-dciancu/unifi-protect-unvr-docker-arm64}"

if [[ -n "${BUILD_NO_CACHE+x}" ]]; then
    opts='--no-cache'
fi

if [[ -n "${BUILD_TEST+x}" ]]; then
    if [[ -n "${BUILD_PRUNE+x}" ]]; then
        docker images | grep "$image_name" | tr -s ' ' | cut -d ' ' -f 2 \
            | xargs -I {} docker rmi -f "${image_name}:{}" || true
        docker buildx prune -f
    fi

    if [[ -n "${BUILD_EDGE+x}" ]]; then
        docker build $opts -f protect.Dockerfile -t "${image_name}:test-edge" .
    fi

    if [[ -n "${BUILD_STABLE+x}" ]] || [[ -z "${BUILD_EDGE+x}" ]]; then
        docker build $opts -f protect.Dockerfile --build-arg PROTECT_STABLE=1 -t "${image_name}:test-stable" --pull .
    fi
else
    if [[ -n "${BUILD_PRUNE+x}" ]]; then
        docker images | grep "$image_name" | tr -s ' ' | cut -d ' ' -f 2 \
            | xargs -I {} docker rmi -f "${image_name}:{}" || true
        docker buildx prune -f
    fi

    if [[ -n "${BUILD_EDGE+x}" ]]; then
        docker build $opts -f protect.Dockerfile -t "${image_name}:edge" .
        if [[ -n "${BUILD_TAG_VERSION+x}" ]]; then
            version="$(docker run --rm "${image_name}:edge" dpkg -s unifi-protect | grep '^Version:' | cut -d ' ' -f 2 | tr -d '\n')"
            docker tag "${image_name}:edge" "${image_name}:v${version}"
            docker tag "${image_name}:edge" "${image_name}:v$(cut -d '.' -f 1-2 <<< "$version")"
            docker tag "${image_name}:edge" "${image_name}:v$(cut -d '.' -f 1 <<< "$version")"
        fi
    fi

    if [[ -n "${BUILD_STABLE+x}" ]] || [[ -z "${BUILD_EDGE+x}" ]]; then
        docker build $opts -f protect.Dockerfile --build-arg PROTECT_STABLE=1 -t "${image_name}:stable" --pull .
        if [[ -n "${BUILD_TAG_VERSION+x}" ]]; then
            firmware_version="$(tr -d '\n' < firmware/version)"
            docker tag "${image_name}:stable" "${image_name}:${firmware_version}"
            version="$(docker run --rm "${image_name}:stable" dpkg -s unifi-protect | grep '^Version:' | cut -d ' ' -f 2 | tr -d '\n')"
            docker tag "${image_name}:stable" "${image_name}:v${version}"
            docker tag "${image_name}:stable" "${image_name}:v$(cut -d '.' -f 1-2 <<< "$version")"
            docker tag "${image_name}:stable" "${image_name}:v$(cut -d '.' -f 1 <<< "$version")"
        fi
    fi
fi
