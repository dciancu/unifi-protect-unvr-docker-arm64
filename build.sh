#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR"

sh build-firmware.sh
sh build-protect.sh
