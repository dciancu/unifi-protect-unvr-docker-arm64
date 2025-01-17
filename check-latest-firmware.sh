#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

FW_UPDATE_URL='https://fw-update.ubnt.com/api/firmware?filter=eq~~platform~~unvr&filter=eq~~channel~~release&sort=-version&limit=10'
LATEST_FIRMWARE="$(wget -q --output-document - "$FW_UPDATE_URL" | jq -r '._embedded.firmware[0]._links.data.href')"
LATEST_REPO_FIRMWARE="$(tr -d '\n' < LATEST_FIRMWARE.txt)"

echo "Latest Firmware: ${LATEST_FIRMWARE}"
echo "Latest Repo Firmware: ${LATEST_REPO_FIRMWARE}"

if [[ "$LATEST_FIRMWARE" == "$LATEST_REPO_FIRMWARE" ]]; then
    echo 'Latest firmware in repo ok.'
    exit 0
else
    echo 'Found newer latest firmware!'
    exit 1
fi
