#!/usr/bin/env bash

set -euo pipefail

if grep 'anonymous_device_id: null' /data/unifi-core/config/settings.yaml; then
    UUID="$(cat /proc/sys/kernel/random/uuid)"
    sed -Ei "s/anonymous_device_id:.*/anonymous_device_id: ${UUID}/g" /data/unifi-core/config/settings.yaml
fi
