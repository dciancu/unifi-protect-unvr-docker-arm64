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
    && apt-get --no-install-recommends -y install postgresql-14 postgresql-9.6

COPY firmware/version /usr/lib/version
COPY files/lib /lib/

ARG UNVR_STABLE
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    --mount=type=bind,source=firmware/debs,target=/opt/debs \
    --mount=type=bind,source=firmware/unifi-protect-deb,target=/opt/unifi-protect-deb \
    set -euo pipefail \
    && UNVR_STABLE="${UNVR_STABLE:-}" \
    && apt-get --no-install-recommends -y install /opt/debs/ubnt-archive-keyring_*_arm64.deb \
    && echo "deb https://apt.artifacts.ui.com `lsb_release -cs` main release" > /etc/apt/sources.list.d/ubiquiti.list \
    && apt-get update \
    # UNVR_STABLE not set
    && test ! -z "$UNVR_STABLE" || apt-get -y --no-install-recommends --force-yes \
        -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
        install /opt/debs/*.deb unifi-protect \
    # UNVR_STABLE set
    && test -z "$UNVR_STABLE" || apt-get -y --no-install-recommends --force-yes \
        -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold' \
        install /opt/debs/*.deb /opt/unifi-protect-deb/*.deb \
    && echo 'exit 0' > /usr/sbin/policy-rc.d \
    && sed -i 's/redirectHostname: unifi//' /usr/share/unifi-core/app/config/default.yaml \
    && sed -i 's/useGrpc:!0/useGrpc:!!0/g' /usr/share/unifi-core/app/service.js \
    && mv /sbin/mdadm /sbin/mdadm.orig \
    && mv /sbin/ubnt-tools /sbin/ubnt-tools.orig \
    && systemctl enable storage_disk dbpermissions fix_hosts \
    && pg_dropcluster --stop 9.6 main \
    && sed -i 's/rm -f/rm -rf/' /sbin/pg-cluster-upgrade \
    && sed -i 's/OLD_DB_CONFDIR=.*/OLD_DB_CONFDIR=\/etc\/postgresql\/9.6\/main/' /sbin/pg-cluster-upgrade \
    && touch /usr/bin/uled-ctrl \
    && chmod +x /usr/bin/uled-ctrl \
    && chown root:root /etc/sudoers.d/* \
    && echo -e '\n\nexport PGHOST=127.0.0.1\n' >> /usr/lib/ulp-go/scripts/envs.sh

COPY files/sbin /sbin/
COPY files/usr /usr/
COPY files/etc /etc/

VOLUME ["/srv", "/data", "/persistent"]

STOPSIGNAL SIGINT
CMD ["/lib/systemd/systemd"]
