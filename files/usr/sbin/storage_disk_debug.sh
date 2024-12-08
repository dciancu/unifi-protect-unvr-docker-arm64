#!/bin/bash

if [[ "${DEBUG:-false}" == 'true' ]]; then
    echo $@ >> /var/log/storage_disk_debug.log
fi
