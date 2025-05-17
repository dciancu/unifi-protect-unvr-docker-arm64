#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

FW_UPDATE_URL='https://fw-update.ubnt.com/api/firmware?filter=eq~~platform~~unvr&filter=eq~~channel~~release&sort=-version&limit=10'
LATEST_FIRMWARE="$(wget -q --output-document - "$FW_UPDATE_URL" | jq -r '._embedded.firmware[0]._links.data.href')"
LATEST_REPO_FIRMWARE="$(tr -d '\n' < firmware.txt)"

echo "Latest Firmware: ${LATEST_FIRMWARE}"
echo "Latest Repo Firmware: ${LATEST_REPO_FIRMWARE}"

if [[ "$LATEST_FIRMWARE" == "$LATEST_REPO_FIRMWARE" ]]; then
    echo -e "${GREEN}Latest firmware in repo up-to-date.${NC}"
    exit 0
else
    echo -e "${RED}Found newer latest firmware!${NC}"
    LATEST_STABLE_FIRMWARE="$(wget -q --output-document - "$FW_UPDATE_URL" \
        | jq -r '._embedded.firmware | map(select(.probability_computed == 1))[0] | ._links.data.href')"
    if [[ "$LATEST_STABLE_FIRMWARE" != "$LATEST_FIRMWARE" ]]; then
        echo -e "${RED}WARN: Latest firmware is not marked as stable!${NC}"
        test -n "${FW_EDGE:-}" && exit 1 || exit 0
    else
        echo -e "${GREEN}Latest firmware is marked as stable.${NC}"
        exit 1
    fi
fi
