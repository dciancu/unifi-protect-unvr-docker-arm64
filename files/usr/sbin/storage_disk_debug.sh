#!/bin/bash

if [[ "${DEBUG:-false}" == 'true' ]]; then
    echo "$0" "$@" >> /var/log/storage_disk_debug.log
fi
