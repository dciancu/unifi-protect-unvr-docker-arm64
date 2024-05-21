#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(dirname "$0")"
cd "${SCRIPT_DIR}/firmware-build"

docker build --no-cache --target firmware-build -t unvr-firmware .

if [ -n "$(ls firmware)" ]; then
    if [ -d firmware-tmp ]; then
        rm -r firmware-tmp
    fi
    mkdir firmware-tmp
    mv firmware/* firmware-tmp/
fi
docker build --output=firmware --target=firmware .
exit_code="$?"
if [ -d firmware-tmp ]; then
    if [ "$exit_code" -ne 0 ]; then
        rm -rf firmware/* || true
        mv firmware-tmp firmware/
    fi
    rm -r firmware-tmp
fi
