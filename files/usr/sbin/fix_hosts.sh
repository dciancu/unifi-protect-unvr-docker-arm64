#!/usr/bin/env bash

set -euo pipefail

HOSTS="$(cat /etc/hosts)"
HOSTNAME="$(hostname)"
if ! grep -q "^127\.0\.1\.1 ${HOSTNAME}" <<< "$HOSTS"; then
    echo -n "$(sed "s/^127\.0\.1\.1.\+/127.0.1.1 ${HOSTNAME}/" <<< "$HOSTS")" > /etc/hosts
fi
