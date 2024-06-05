#!/usr/bin/env bash

set -euo pipefail

while inotifywait -e close_write /etc/hostname &> /dev/null; do
    HOSTS="$(cat /etc/hosts)"
    HOSTNAME="$(tr -d '\n' < /etc/hostname)"
    if ! grep -q "^127\.0\.1\.1 ${HOSTNAME}" <<< "$HOSTS"; then
        echo -n "$(sed "s/^127\.0\.1\.1.\+/127.0.1.1 ${HOSTNAME}/" <<< "$HOSTS")" > /etc/hosts
    fi
    unset HOSTS HOSTNAME
done
