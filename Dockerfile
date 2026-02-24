# multi-stage build Protect


FROM debian:trixie AS firmware-base
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private --mount=target=/var/cache/apt,type=cache,sharing=private \
    set -euo pipefail \
    && apt-get update \
    && apt-get install -y apt-transport-https ca-certificates \
    && sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get dist-upgrade -y \
    && apt-get --purge autoremove -y \
    && apt-get install -y wget jq binwalk dpkg-repack


FROM firmware-base AS firmware
ARG FW_URL
ARG FW_EDGE
ARG FW_ALL_DEBS
ARG FW_UNSTABLE
ARG FW_UPDATE_URL='https://fw-update.ubnt.com/api/firmware?filter=eq~~platform~~unvr&filter=eq~~channel~~release&sort=-version&limit=10'
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

COPY firmware.txt /opt/

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && FW_URL="${FW_URL:-}" \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get dist-upgrade -y \
    && apt-get --purge autoremove -y \
    && mkdir -p /opt/firmware-build && cd /opt/firmware-build \
    && if [ -z "$FW_URL" ] && [ -z "${FW_EDGE:-}" ]; then FW_URL="$(tr -d '\n' < /opt/firmware.txt)"; fi  \
    # if FW_URL not set \
    && if [ -z "$FW_URL" ]; then { shopt -s lastpipe && wget -q --output-document - "$FW_UPDATE_URL" | \
        { if [ -n "${FW_UNSTABLE:-}" ]; then \
            # FW_UNSTABLE set, skip probability_computed \
            jq -r '._embedded.firmware[0]._links.data.href'; \
        else \
            # FW_UNSTABLE not set, check probability_computed \
            jq -r '._embedded.firmware | map(select(.probability_computed == 1))[0] | ._links.data.href'; \
        fi; } | \
        FW_URL="$(</dev/stdin)" && shopt -u lastpipe; }; fi \
    && echo "FW_URL: ${FW_URL}" \
    && wget --no-verbose --show-progress --progress=dot:giga -O fwupdate.bin "$FW_URL" \
    && sha1sum fwupdate.bin | tee fwupdate.sha1 \
    && useradd --shell /bin/bash build \
    && binwalk --run-as=build -e fwupdate.bin \
    && rm fwupdate.bin \
    && cp _fwupdate.bin.extracted/squashfs-root/usr/lib/version . \
    && dpkg-query --admindir=_fwupdate.bin.extracted/squashfs-root/var/lib/dpkg/ -W -f='${package} | ${Maintainer}\n' | \
        grep -E '@ubnt.com|@ui.com' | cut -d '|' -f 1 > packages.txt \
    && cat packages.txt \
    && mkdir debs-build && cd debs-build \
    && while read pkg; do \
        dpkg-repack --root=../_fwupdate.bin.extracted/squashfs-root/ --arch=arm64 "$pkg"; \
    done < ../packages.txt \
    && ls -lh \
    # ALL_DEBS set \
    && if [ -n "${FW_ALL_DEBS:-}" ]; then mkdir ../all-debs && cp * ../all-debs/; fi \
    && mkdir ../debs \
    && cp ubnt-archive-keyring_* unifi-core_* ubnt-tools_* ulp-go_* unifi-assets-unvr_* unifi-directory_* uos_* \
        uos-agent_* uos-discovery-client_* node* unifi-email-templates-all_* ../debs/ \
    && mkdir ../unifi-protect-deb \
    && cp unifi-protect_* ../unifi-protect-deb/ \
    && cd .. \
    && rm -r _fwupdate.bin.extracted debs-build \
    && (cd / && rm -rf $(ls -A | grep -vE 'opt|sys|proc|dev'); exit 0) && exit 0


FROM arm64v8/debian:11 AS protect

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private --mount=target=/var/cache/apt,type=cache,sharing=private \
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

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=private --mount=target=/var/cache/apt,type=cache,sharing=private \
    set -euo pipefail \
    && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null \
    && echo "deb https://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/postgresql.list \
    && apt-get update \
    && apt-get --no-install-recommends -y install postgresql-14

COPY files/lib /lib/

COPY --from=firmware /opt/firmware-build/version /usr/lib/version
COPY --from=firmware /opt/firmware-build/debs /opt/debs
COPY --from=firmware /opt/firmware-build/unifi-protect-deb /opt/unifi-protect-deb

ARG PROTECT_STABLE
ARG PROTECT_URL
ARG AIFC_URL
ARG AIFC_STABLE_URL="https://fw-download.ubnt.com/data/ai-feature-console/1152-uos-deb11-arm64-1.9.5-aa073f02-faec-4659-b71a-68fe793233f2.deb"
ARG PROTECT_UPDATE_URL="https://fw-update.ubnt.com/api/firmware-latest?filter=eq~~product~~unifi-protect&filter=eq~~channel~~release&filter=eq~~platform~~uos-deb11-arm64"
ARG AIFC_UPDATE_URL='https://fw-update.ubnt.com/api/firmware-latest?filter=eq~~product~~ai-feature-console&filter=eq~~channel~~release&filter=eq~~platform~~uos-deb11-arm64'
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    set -euo pipefail \
    && AIFC_URL="${AIFC_URL:-}" \
    && PROTECT_URL="${PROTECT_URL:-}" \
    && PROTECT_STABLE="${PROTECT_STABLE:-}" \
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
            PROTECT_URL="$(wget -q --output-document - "$PROTECT_UPDATE_URL" | jq -r '._embedded.firmware[0]._links.data.href')"; \
        fi \
        && if [ -z "$AIFC_URL" ]; then \
            AIFC_URL="$(wget -q --output-document - "$AIFC_UPDATE_URL" | jq -r '._embedded.firmware[0]._links.data.href')"; \
        fi \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/unifi-protect.deb "$PROTECT_URL" \
        && wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/ai-feature-console.deb /opt/unifi-protect.deb \
        && rm /opt/ai-feature-console.deb /opt/unifi-protect.deb; \
    fi \
    # PROTECT_STABLE set \
    && if [ -n "$PROTECT_STABLE" ]; then \
        wget --no-verbose --show-progress --progress=dot:giga -O /opt/ai-feature-console.deb "$AIFC_STABLE_URL" \
        && apt-get -y --no-install-recommends -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
            install /opt/debs/*.deb /opt/ai-feature-console.deb /opt/unifi-protect-deb/*.deb \
        && rm /opt/ai-feature-console.deb; \
    fi \
    && rm -r /opt/debs /opt/unifi-protect-deb

RUN \
    # Enable storage via ustorage instead of grpc ustate. \
    # This will most likely need to be updated with each firmware release. \
    if ! sed -i '/return Qe()?s.push/{s//return Qe(),!0?s.push/;h};${x;/./{x;q0};x;q1}' /usr/share/unifi-core/app/service.js; then \
        echo 'ERROR: sed failed, check unifi-core/app/service.js contents!' && exit 1; \
    fi \
    && echo 'exit 0' > /usr/sbin/policy-rc.d \
    && mv /sbin/mdadm /sbin/mdadm.orig \
    && mv /sbin/ubnt-tools /sbin/ubnt-tools.orig \
    && systemctl enable storage_disk dbpermissions fix_hosts fix_apt_ubiquiti_sources \
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

LABEL project_version='5.8.6'
LABEL PROTECT_URL=${PROTECT_URL}
LABEL AIFC_URL=${AIFC_URL}
LABEL PROTECT_STABLE=${PROTECT_STABLE}
LABEL PROTECT_UPDATE_URL=${PROTECT_UPDATE_URL}
LABEL AIFC_STABLE_URL=${AIFC_STABLE_URL}
LABEL AIFC_UPDATE_URL=${AIFC_UPDATE_URL}
