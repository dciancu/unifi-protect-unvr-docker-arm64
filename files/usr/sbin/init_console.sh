#!/usr/bin/env bash

set -euo pipefail

if grep 'anonymous_device_id: null' /data/unifi-core/config/settings.yaml; then
    UUID="$(cat /proc/sys/kernel/random/uuid)"
    # maybe UUID='00000000-0000-0000-0000-000000000000' also works for better privacy, but has not been tested
    sed -Ei "s/anonymous_device_id:.*/anonymous_device_id: ${UUID}/g" /data/unifi-core/config/settings.yaml
fi
