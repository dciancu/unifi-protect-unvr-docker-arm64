#!/bin/bash

for e in $(tr "\000" "\n" < /proc/1/environ); do
    eval "export $e"
done

debug="${DEBUG:-false}"

if [[ "$debug" == 'true' || "${DEBUG_UNIFI_CORE:-false}" == 'true' ]]; then
    cp -a /usr/share/unifi-core/app/config/default.yaml /usr/share/unifi-core/app/config/default.yaml.bak
    sed -Ei "s/defaultLevel: '.+'/defaultLevel: 'debug'/g" /usr/share/unifi-core/app/config/default.yaml
elif [ -f /usr/share/unifi-core/app/config/default.yaml.bak ]; then
    mv /usr/share/unifi-core/app/config/default.yaml.bak /usr/share/unifi-core/app/config/default.yaml
fi

disk="${STORAGE_DISK:-/dev/sda1}"
echo '#!/bin/bash' > /etc/default/storage_disk
echo "STORAGE_DISK=${disk}" >> /etc/default/storage_disk

if [[ "$debug" == 'true' || "${DEBUG_STORAGE:-false}" == 'true' ]]; then
    echo 'echo "$0" "$@" >> /var/log/storage_disk_debug.log' >> /etc/default/storage_disk
    echo '' >> /var/log/storage_disk_debug.log
    echo '=== CONTAINER START ===' >> /var/log/storage_disk_debug.log
    echo '' >> /var/log/storage_disk_debug.log
fi
