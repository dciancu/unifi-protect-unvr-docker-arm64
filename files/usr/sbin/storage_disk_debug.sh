#!/bin/bash

debug="${DEBUG:-false}"
if [[ "$debug" == 'true' ]]; then
    echo "$0" "$@" >> /var/log/storage_disk_debug.log
fi
