FROM unvr-firmware-base AS firmware
ARG FW_URL
ARG FW_EDGE
ARG FW_ALL_DEBS
ARG FW_UNSTABLE
ARG FW_UPDATE_URL='https://fw-update.ubnt.com/api/firmware?filter=eq~~platform~~unvr&filter=eq~~channel~~release&sort=-version&limit=10'
ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/usr/bin/env", "bash", "-c"]

COPY firmware.txt /opt/

RUN --mount=target=/var/lib/apt/lists,type=cache --mount=target=/var/cache/apt,type=cache \
    --mount=type=bind,target=/opt/firmware,source=firmware,ro \
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
    && if test -f /opt/firmware/fwupdate.sha1 && cat /opt/firmware/fwupdate.sha1 && sha1sum -c /opt/firmware/fwupdate.sha1; then \
        rm fwupdate.bin \
        && cp -a /opt/firmware/* . \
        && ls -lhR \
        && (cd / && rm -rf $(ls -A | grep -vE 'opt|sys|proc|dev'); exit 0) \
        && exit 0; \
    fi \
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
    && cp ubnt-archive-keyring_* unifi-core_* ubnt-tools_* ulp-go_* unifi-assets-unvr_* unifi-directory_* uos_* node* \
        unifi-email-templates-all_* ../debs/ \
    && mkdir ../unifi-protect-deb \
    && cp unifi-protect_* ../unifi-protect-deb/ \
    && cd .. \
    && rm -r _fwupdate.bin.extracted debs-build \
    && (cd / && rm -rf $(ls -A | grep -vE 'opt|sys|proc|dev'); exit 0) && exit 0
