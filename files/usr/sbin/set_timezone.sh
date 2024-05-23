#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${TZ+x}" ]] || [[ ! -f "/usr/share/zoneinfo/${TZ}" ]]; then
    TZ='UTC'
fi

echo "$TZ" > /etc/timezone
