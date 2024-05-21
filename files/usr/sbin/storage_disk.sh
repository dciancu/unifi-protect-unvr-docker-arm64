#!/bin/bash

for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

disk="${STORAGE_DISK:-/dev/sda1}"
echo "STORAGE_DISK=${disk}" > /etc/default/storage_disk
