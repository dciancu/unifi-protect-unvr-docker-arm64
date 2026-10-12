FROM arm64v8/debian:13 AS protect

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get -y dist-upgrade \
    && apt-get --purge autoremove -y \
    # inotify-tools is used by fix_hosts.sh script \
    # net-tools (arp command) is needed by Protect to adopt ONVIF cameras \
    && apt-get --no-install-recommends -y install \
        vim \
        adduser \
        inotify-tools \
        curl \
        wget \
        mount \
        psmisc \
        dpkg \
        apt \
        lsb-release \
        sudo \
        gnupg \
        apt-transport-https \
        ca-certificates \
        dirmngr \
        mdadm \
        iproute2 \
        ethtool \
        procps \
        cron \
        lvm2 \
        systemd \
        systemd-timesyncd \
        sysstat \
        net-tools \
        jq \
        # chattr, used by fix_apt_ubiquiti_sources.sh, is no longer installed by default on debian 13 \
        e2fsprogs \
    && find /etc/systemd/system \
        /lib/systemd/system \
        -path '*.wants/*' \
        -not -name '*journald*' \
        -not -name '*systemd-tmpfiles*' \
        -not -name '*systemd-user-sessions*' \
        -exec rm \{} \;

RUN set -euo pipefail \
    && curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
        | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/debian `lsb_release -cs` nginx" \
        | sudo tee /etc/apt/sources.list.d/nginx.list \
    && echo 'Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n' \
        | sudo tee /etc/apt/preferences.d/99nginx \
    && cat /etc/apt/preferences.d/99nginx

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
    && echo "deb https://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update \
    && apt-get --no-install-recommends -y install postgresql-14

COPY firmware/version /usr/lib/version
COPY files/etc/systemd /etc/systemd/

ARG PROTECT_STABLE
# UniFi Protect
ARG PROTECT_URL
# AI features on console
ARG AIFC_CNS_URL
# AI features controller
ARG AIFC_CTR_URL
# Unifi Protect Media Server
ARG MS_URL
# Media Server Recording Service
ARG MSR_URL
# Media Server Playback Service
ARG MSP_URL
# Media Server Trascoding Service
ARG MST_URL
# Media Server Ffmpeg
ARG MSF_URL
# Unifi Protect Device Service
ARG DS_URL
# UniFi Protect evidence verification CLI
ARG PROTECT_VERIFY_URL
ARG AIFC_CNS_STABLE_URL="https://fw-download.ubnt.com/data/ai-feature-console/a678-uos-deb13-arm64-1.11.0-636c4bf3-485f-4231-a1ee-902e5024b4b1.deb"
ARG AIFC_CTR_STABLE_URL="https://fw-download.ubnt.com/data/ai-feature-controller/6c45-uos-deb13-arm64-2.0.17-725ca246-0120-46c3-a5fc-037e3dd6b698.deb"
ARG DS_STABLE_URL="https://fw-download.ubnt.com/data/ds/5ec4-uos-deb13-arm64-7.2.14-f090486c-0751-4ca2-8ddb-66f6d78a278f.deb"
ARG MSF_STABLE_URL="https://fw-download.ubnt.com/data/msf/0332-uos-deb13-arm64-0.0.7-680bcb93-21c0-4b72-8592-3f5f3166189c.deb"
ARG PROTECT_VERIFY_STABLE_URL="https://fw-download.ubnt.com/data/protect-verify/1f90-uos-deb13-arm64-0.9.1-80cbd13f-7e94-481f-adb0-07ad8a1f38c8.deb"
# the trixie apt repo only carries ms/msr/msp/mst 5.1.290, Protect 7.2.105 needs >= 5.1.309
ARG MS_STABLE_URL="https://fw-download.ubnt.com/data/ms/3cea-uos-deb13-arm64-5.1.309-959cf5b1-3d58-4cf4-a4f3-257f29f655c8.deb"
ARG MSR_STABLE_URL="https://fw-download.ubnt.com/data/msr/24fe-uos-deb13-arm64-5.1.309-aaba59d2-719d-48ba-94ef-284421d8221c.deb"
ARG MSP_STABLE_URL="https://fw-download.ubnt.com/data/msp/a41c-uos-deb13-arm64-5.1.309-75711aa0-f3ca-4cc8-9c29-a2fe91cee284.deb"
ARG MST_STABLE_URL="https://fw-download.ubnt.com/data/mst/8435-uos-deb13-arm64-5.1.309-bb0c2a78-3b26-43be-a441-a95a0716bf98.deb"
ARG RCLONE_STABLE_URL="https://fw-download.ubnt.com/data/unifi-rclone/9d16-uos-deb13-arm64-1.74.4-9790-8567b01b-5d50-4723-a54b-eb59fae8f931.deb"
ARG DEB_UPDATE_URL="https://fw-update.ubnt.com/api/firmware-latest?filter=eq~~product~~{product}&filter=eq~~channel~~release&filter=eq~~platform~~uos-deb13-arm64"
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    --mount=type=bind,source=firmware/debs,target=/opt/debs \
    --mount=type=bind,source=firmware/unifi-protect-deb,target=/opt/unifi-protect-deb \
    set -euo pipefail \
    && systemctl enable systemd-timesyncd.service \
    && systemctl enable systemd-time-wait-sync.service \
    && apt-get --no-install-recommends -y install /opt/debs/ubnt-archive-keyring_*_arm64.deb \
    && echo "deb https://apt.artifacts.ui.com `lsb_release -cs` release" > /etc/apt/sources.list.d/ubiquiti.list \
    && apt-get update \
    && mv /bin/systemctl /bin/systemctl.tmp \
    && echo -e '#!/bin/bash\necho 0' > /bin/systemctl \
    && chmod +x /bin/systemctl \
    && apt-get --no-install-recommends -y install /opt/debs/uos-discovery-client_*_arm64.deb \
    && mv /bin/systemctl.tmp /bin/systemctl \
    && systemctl enable uos-discovery-client.service \
    # install /usr/bin/ms (ms package) shared libs not set in package deps \
    && apt-get --no-install-recommends -y install libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
        libgstreamer-plugins-bad1.0-0 libglib2.0-0t64 \
    # PROTECT_STABLE not set \
    && if [ -z "${PROTECT_STABLE:-}" ]; then \
        if [ -z "${PROTECT_URL:-}" ]; then \
            PROTECT_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/unifi-protect/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "PROTECT_URL=${PROTECT_URL}"; \
        fi \
        && if [ -z "${AIFC_CNS_URL:-}" ]; then \
            AIFC_CNS_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/ai-feature-console/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "AIFC_CNS_URL=${AIFC_CNS_URL}"; \
        fi \
        && if [ -z "${AIFC_CTR_URL:-}" ]; then \
            AIFC_CTR_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/ai-feature-controller/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "AIFC_CTR_URL=${AIFC_CTR_URL}"; \
        fi \
        && if [ -z "${MS_URL:-}" ]; then \
            MS_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/ms/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MS_URL=${MS_URL}"; \
        fi \
        && if [ -z "${MSR_URL:-}" ]; then \
            MSR_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/msr/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MSR_URL=${MSR_URL}"; \
        fi \
        && if [ -z "${MSP_URL:-}" ]; then \
            MSP_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/msp/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MSP_URL=${MSP_URL}"; \
        fi \
        && if [ -z "${MST_URL:-}" ]; then \
            MST_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/mst/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MST_URL=${MST_URL}"; \
        fi \
        && if [ -z "${MSF_URL:-}" ]; then \
            MSF_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/msf/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MSF_URL=${MSF_URL}"; \
        fi \
        && if [ -z "${DS_URL:-}" ]; then \
            DS_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/ds/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "DS_URL=${DS_URL}"; \
        fi \
        && if [ -z "${PROTECT_VERIFY_URL:-}" ]; then \
            PROTECT_VERIFY_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/protect-verify/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "PROTECT_VERIFY_URL=${PROTECT_VERIFY_URL}"; \
        fi \
        && RCLONE_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/unifi-rclone/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
        && echo "RCLONE_URL=${RCLONE_URL}" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-rclone.deb "$RCLONE_URL" \
        # unifi-user-assets (needed by Protect >= 7.3) and its unifi-face-shared-lib dependency are not in the trixie apt repo either \
        && USER_ASSETS_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/unifi-user-assets/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
        && echo "USER_ASSETS_URL=${USER_ASSETS_URL}" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-user-assets.deb "$USER_ASSETS_URL" \
        && FACE_LIB_URL="$(wget -q -O - "$(printf "$DEB_UPDATE_URL" | sed 's/{product}/unifi-face-shared-lib/')" | jq -r '._embedded.firmware[0]._links.data.href')" \
        && echo "FACE_LIB_URL=${FACE_LIB_URL}" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-face-shared-lib.deb "$FACE_LIB_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-protect.deb "$PROTECT_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_CNS_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-controller.deb "$AIFC_CTR_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ms.deb "$MS_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msr.deb "$MSR_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msp.deb "$MSP_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/mst.deb "$MST_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msf.deb "$MSF_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ds.deb "$DS_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/protect-verify.deb "$PROTECT_VERIFY_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/*.deb \
        && rm /opt/*.deb; \
    fi \
    # PROTECT_STABLE set \
    && if [ -n "${PROTECT_STABLE:-}" ]; then \
        wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_CNS_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-controller.deb "$AIFC_CTR_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ds.deb "$DS_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ms.deb "$MS_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msr.deb "$MSR_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msp.deb "$MSP_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/mst.deb "$MST_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msf.deb "$MSF_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/protect-verify.deb "$PROTECT_VERIFY_STABLE_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-rclone.deb "$RCLONE_STABLE_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/*.deb /opt/unifi-protect-deb/*.deb \
        && rm /opt/*.deb; \
    fi

RUN \
    # Mock StorageAPIClient of grpc ustate. \
    sedSearch="import {StorageAPIClient}from'@ubnt/unifi-protobufs/unifi/firmware/storage/v2/api_grpc_pb.js';" \
    && sedReplace="import {StorageAPIClient}from'./mockStorageAPIClient.js';" \
    && if ! sed -i ':a;N;$!ba;s|'"$sedSearch"'|'"$sedReplace"'|g;t;q1' /usr/share/unifi-core/app/service.js; then \
        echo 'ERROR: sed for StorageAPIClient mock failed, check unifi-core/app/service.js contents!' && exit 1; \
    fi \
    && echo 'exit 0' > /usr/sbin/policy-rc.d \
    && mv /sbin/mdadm /sbin/mdadm.orig \
    && mv /sbin/ubnt-tools /sbin/ubnt-tools.orig \
    && systemctl enable storage_disk dbpermissions fix_hosts fix_apt_ubiquiti_sources init_console ustated-mock \
    && sed -i 's/rm -f/rm -rf/' /sbin/pg-cluster-upgrade \
    && touch /usr/bin/uled-ctrl \
    && chmod +x /usr/bin/uled-ctrl \
    && chown root:root /etc/sudoers.d/* \
    && echo -e '\n\nexport PGHOST=127.0.0.1\n' >> /usr/lib/ulp-go/scripts/envs.sh

COPY files/sbin /sbin/
COPY files/usr /usr/

VOLUME ["/srv", "/data", "/persistent"]

STOPSIGNAL SIGINT
CMD ["/lib/systemd/systemd"]

LABEL PROTECT_STABLE=${PROTECT_STABLE}
LABEL AIFC_CNS_STABLE_URL=${AIFC_CNS_STABLE_URL}
LABEL AIFC_CTR_STABLE_URL=${AIFC_CTR_STABLE_URL}
LABEL DS_STABLE_URL=${DS_STABLE_URL}
LABEL PROTECT_URL=${PROTECT_URL}
LABEL PROTECT_VERIFY_URL=${PROTECT_VERIFY_URL}
LABEL AIFC_CNS_URL=${AIFC_CNS_URL}
LABEL AIFC_CTR_URL=${AIFC_CTR_URL}
LABEL MS_URL=${MS_URL}
LABEL MSR_URL=${MSR_URL}
LABEL MSP_URL=${MSP_URL}
LABEL MST_URL=${MST_URL}
LABEL MSF_URL=${MSF_URL}
LABEL DS_URL=${DS_URL}
