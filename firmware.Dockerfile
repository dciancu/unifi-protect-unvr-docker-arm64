FROM unvr-firmware-base AS firmware
ARG ALL_DEBS
ARG FW_URL
ARG FW_UPDATE_URL='https://fw-update.ubnt.com/api/firmware?filter=eq~~platform~~unvr&filter=eq~~channel~~release&sort=-version&limit=10'
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]
RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    --mount=type=bind,target=/opt/firmware,source=firmware,ro \
    set -euo pipefail \
    && FW_URL="${FW_URL:-}" \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get dist-upgrade -y \
    && apt-get --purge autoremove -y \
    && mkdir -p /opt/firmware-build && cd /opt/firmware-build \
    && test ! -z "$FW_URL" || wget -q --output-document - "$FW_UPDATE_URL" | \
        jq -r '._embedded.firmware | map(select(.probability_computed == 1))[0] | ._links.data.href' | \
        wget --no-verbose --show-progress --progress=dot:giga -O fwupdate.bin -i - \
    && test -z "$FW_URL" || wget --no-verbose --show-progress --progress=dot:giga -O fwupdate.bin "$FW_URL" \
    && if test -f /opt/firmware/fwupdate.sha1 && sha1sum -c /opt/firmware/fwupdate.sha1; then \
        rm fwupdate.bin \
        && cp -a /opt/firmware/* . \
        && (cd / && rm -rf $(ls -A | grep -vE 'opt|sys|proc|dev'); exit 0) \
        && exit 0; \
    fi \
    && sha1sum fwupdate.bin > fwupdate.sha1 \
    && adduser --gecos '' --shell /bin/bash --disabled-password --disabled-login build \
    && binwalk --run-as=build -e fwupdate.bin \
    && rm fwupdate.bin \
    && cp _fwupdate.bin.extracted/squashfs-root/usr/lib/version . \
    && dpkg-query --admindir=_fwupdate.bin.extracted/squashfs-root/var/lib/dpkg/ -W -f='${package} | ${Maintainer}\n' | \
        grep -E '@ubnt.com|@ui.com' | cut -d '|' -f 1 > packages.txt \
    && mkdir debs-build && cd debs-build \
    && while read pkg; do \
        dpkg-repack --root=../_fwupdate.bin.extracted/squashfs-root/ --arch=arm64 "$pkg"; \
    done < ../packages.txt \
    && test -z "${ALL_DEBS:-}" || (mkdir ../all-debs && cp * ../all-debs/) \
    && mkdir ../debs \
    && cp ubnt-archive-keyring* unifi-core* ubnt-tools* ulp-go* unifi-assets-unvr* ../debs/ \
    && mkdir ../unifi-protect-deb \
    && cp unifi-protect* ../unifi-protect-deb/ \
    && cd .. \
    && rm -r _fwupdate.bin.extracted debs-build \
    && (cd / && rm -rf $(ls -A | grep -vE 'opt|sys|proc|dev'); exit 0) && exit 0
