FROM arm64v8/debian:11 AS protect

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list \
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
COPY files/etc /etc/

ARG PROTECT_STABLE
# UniFi Protect
ARG PROTECT_URL
# AI features on console
ARG AIFC_URL
# Unifi Protect Media Server
ARG MS_URL
# Media Server Recording Service
ARG MSR_URL
# Media Server Playback Service
ARG MSP_URL
# Media Server Trascoding Service
ARG MST_URL
# Unifi Protect Device Service
ARG DS_URL
ARG AIFC_STABLE_URL="https://fw-download.ubnt.com/data/ai-feature-console/f3c8-uos-deb11-arm64-1.9.15-3316d322-b5da-4f44-84a3-e823dfef82be.deb"
ARG DEB_UPDATE_URL="https://fw-update.ubnt.com/api/firmware-latest?filter=eq~~product~~{product}&filter=eq~~channel~~release&filter=eq~~platform~~uos-deb11-arm64"
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    --mount=type=bind,source=firmware/debs,target=/opt/debs \
    --mount=type=bind,source=firmware/unifi-protect-deb,target=/opt/unifi-protect-deb \
    set -euo pipefail \
    && DS_URL="${DS_URL:-}" \
    && MS_URL="${MS_URL:-}" \
    && MSR_URL="${MSR_URL:-}" \
    && MSP_URL="${MSP_URL:-}" \
    && MST_URL="${MST_URL:-}" \
    && AIFC_URL="${AIFC_URL:-}" \
    && PROTECT_URL="${PROTECT_URL:-}" \
    && PROTECT_STABLE="${PROTECT_STABLE:-}" \
    && systemctl enable systemd-timesyncd.service \
    && systemctl enable systemd-time-wait-sync.service \
    && apt-get --no-install-recommends -y install /opt/debs/ubnt-archive-keyring_*_arm64.deb \
    && echo "deb https://apt.artifacts.ui.com `lsb_release -cs` main release" > /etc/apt/sources.list.d/ubiquiti.list \
    && apt-get update \
    && mv /bin/systemctl /bin/systemctl.tmp \
    && echo -e '#!/bin/bash\necho 0' > /bin/systemctl \
    && chmod +x /bin/systemctl \
    && apt-get --no-install-recommends -y install /opt/debs/uos-discovery-client_*_arm64.deb \
    && mv /bin/systemctl.tmp /bin/systemctl \
    && systemctl enable uos-discovery-client.service \
    # install /usr/bin/ms (ms package) shared libs not set in package deps \
    && apt-get --no-install-recommends -y install libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 libglib2.0-0 \
    # PROTECT_STABLE not set \
    && if [ -z "$PROTECT_STABLE" ]; then \
        if [ -z "$PROTECT_URL" ]; then \
            PROTECT_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/unifi-protect/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "PROTECT_URL=${PROTECT_URL}"; \
        fi \
        && if [ -z "$AIFC_URL" ]; then \
            AIFC_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/ai-feature-console/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "AIFC_URL=${AIFC_URL}"; \
        fi \
        && if [ -z "$MS_URL" ]; then \
            MS_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/ms/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MS_URL=${MS_URL}"; \
        fi \
        && if [ -z "$MSR_URL" ]; then \
            MSR_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/msr/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MSR_URL=${MSR_URL}"; \
        fi \
        && if [ -z "$MSP_URL" ]; then \
            MSP_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/msp/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MSP_URL=${MSP_URL}"; \
        fi \
        && if [ -z "$MST_URL" ]; then \
            MST_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/mst/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "MST_URL=${MST_URL}"; \
        fi \
        && if [ -z "$DS_URL" ]; then \
            DS_URL="$(wget -q --output-document - "$(printf "$DEB_UPDATE_URL" | sed "s/{product}/ds/")" | jq -r '._embedded.firmware[0]._links.data.href')" \
            && echo "DS_URL=${DS_URL}"; \
        fi \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-protect.deb "$PROTECT_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ms.deb "$MS_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msr.deb "$MSR_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/msp.deb "$MSP_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/mst.deb "$MST_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ds.deb "$DS_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/ai-feature-console.deb /opt/ms.deb /opt/msr.deb /opt/msp.deb /opt/mst.deb \
                /opt/ds.deb /opt/unifi-protect.deb \
        && rm /opt/ai-feature-console.deb /opt/ms.deb /opt/msr.deb /opt/msp.deb /opt/mst.deb /opt/ds.deb \
            /opt/unifi-protect.deb; \
    fi \
    # PROTECT_STABLE set \
    && if [ -n "$PROTECT_STABLE" ]; then \
        wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_STABLE_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/ai-feature-console.deb /opt/unifi-protect-deb/*.deb \
        && rm /opt/ai-feature-console.deb; \
    fi

RUN \
    # Enable storage via ustorage instead of grpc ustate. \
    # This will most likely need to be updated with each firmware release. \
    if ! sed -i '/return Qe()?s.push/{s//return Qe(),!0?s.push/;h};${x;/./{x;q0};x;q1}' /usr/share/unifi-core/app/service.js; then \
        echo 'ERROR: sed failed, check unifi-core/app/service.js contents!' && exit 1; \
    fi \
    && echo 'exit 0' > /usr/sbin/policy-rc.d \
    && mv /sbin/mdadm /sbin/mdadm.orig \
    && mv /sbin/ubnt-tools /sbin/ubnt-tools.orig \
    && systemctl enable storage_disk dbpermissions fix_hosts fix_apt_ubiquiti_sources init_console \
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
LABEL AIFC_STABLE_URL=${AIFC_STABLE_URL}
LABEL PROTECT_URL=${PROTECT_URL}
LABEL AIFC_URL=${AIFC_URL}
LABEL MS_URL=${MS_URL}
LABEL MSR_URL=${MSR_URL}
LABEL MSP_URL=${MSP_URL}
LABEL MST_URL=${MST_URL}
LABEL DS_URL=${DS_URL}
