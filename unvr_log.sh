#!/bin/bash

set -euo pipefail

function print_usage() {
    echo 'Usage: unvr_log.sh on|off'
    echo 'Check logs at /var/log/storage_disk_debug.log'
}

if [ "$#" -eq 0 ]; then
    print_usage
    exit
fi

if ! command -v ustorage &> /dev/null; then
    echo 'ERROR: missing ustorage'
    exit 1
fi
USTORAGE_PATH="$(which ustorage)"

if [ "$1" = 'on' ]; then
    cp -a "$USTORAGE_PATH" "${USTORAGE_PATH}.bak"
    mv "$USTORAGE_PATH" "${USTORAGE_PATH}.orig"
    echo '#!/bin/bash' > "$USTORAGE_PATH"
    echo 'echo "$0" "$@" >> /var/log/storage_disk_debug.log' >> "$USTORAGE_PATH"
    echo "${USTORAGE_PATH}.orig" '$@' >> "$USTORAGE_PATH"
    chmod +x "$USTORAGE_PATH"
elif [ "$1" = 'off' ]; then
    mv "${USTORAGE_PATH}.orig" "$USTORAGE_PATH"
    rm "${USTORAGE_PATH}.bak"
else
    print_usage
fi
