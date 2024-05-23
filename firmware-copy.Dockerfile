FROM scratch AS firmware-copy
COPY --from=unvr-firmware /opt/firmware-build /
