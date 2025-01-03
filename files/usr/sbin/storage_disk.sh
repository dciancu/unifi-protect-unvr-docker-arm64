#!/bin/bash

for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

debug="${DEBUG:-false}"
disk="${STORAGE_DISK:-/dev/sda1}"
echo '#!/bin/bash' > /etc/default/storage_disk
echo "DEBUG=${debug}" > /etc/default/storage_disk
echo "STORAGE_DISK=${disk}" >> /etc/default/storage_disk
echo 'source /usr/sbin/storage_disk_debug.sh' >> /etc/default/storage_disk

if [[ "$debug" == 'true' ]]; then
    echo '' >> /var/log/storage_disk_debug.log
    echo '=== CONTAINER START ===' >> /var/log/storage_disk_debug.log
    echo '' >> /var/log/storage_disk_debug.log
fi
