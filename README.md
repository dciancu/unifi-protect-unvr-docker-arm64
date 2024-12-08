# UniFi Protect UNVR Docker container for arm64

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/F8zvFL89rXf6pgQo3twuVc/5tkZtrshQpSz4fo3k8M7ZZ/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/F8zvFL89rXf6pgQo3twuVc/5tkZtrshQpSz4fo3k8M7ZZ/tree/main)

Run UniFi Protect UNVR in Docker on ARM64 hardware.

> [!IMPORTANT]
> Disconnect the docker host from the internet during the initial console setup, else it will auto update and may
> break the container.  
> Also remember to disable auto update of the console and applications in the console settings.  
> Make sure you have read the below sections on [Issues running systemd inside docker](#issues-running-systemd-inside-docker) and [Issues with remote access](#issues-with-remote-access).

> [!TIP]
> Works on Raspberry Pi (tested with Pi 4 model B 4GB on Debian 12 Bookworm)

## Usage

**Docker Hub Image: [dciancu/unifi-protect-unvr-docker-arm64](https://hub.docker.com/r/dciancu/unifi-protect-unvr-docker-arm64)**  
Tags:
- **`stable - recommended`**, uses Protect version packaged in UNVR firmware
- `edge` - uses latest Protect version (may not always work)
- `Firmware (UniFi OS) specific version` - uses Protect version packaged in UNVR firmware (alias of stable tag)
- `Protect specific version` - alias of stable and edge tags with Protect version

Run the container using `docker compose` with the provided `docker-compose.yml`.  
**Make sure you have read the below section on [Issues running systemd inside docker](#issues-running-systemd-inside-docker).**

### Config

Create a new `docker-compose.override.yml` file and adjust below content for your configuration:
```
services:
  unifi-protect:
    environment:
      - STORAGE_DISK=/dev/sda
      - TZ=UTC
# Set DEBUG mode to enable storage disk operations logging
#      - DEBUG=true
# If needed to mount device inside container.
#    devices:
#      - /dev/sda:/dev/sda
```
`STORAGE_DISK` should point to your disk holding the `storage` folder volume (see `docker-compose.yml`). **Make sure you have access to the device inside the container**, or mount it using `devices` key in `docker-compose.override.yml`.  
`TZ` sets the timezone inside the container and is used by Protect for camera and events timestamp, be sure to set the same value in console settings. Valid timezones inside the container are at `/usr/share/zoneinfo`.

## Setup

> [!IMPORTANT]
> Protect requires `IPv6` enabled (even if blocked by firewall or not routed) and make sure ports used by Protect are not in use by other services/images (`80`, `443` etc.).

When you run the image for the first time, you have to go through the initial console setup, find the host IP address and
navigate to `http://host-ip`.  
Make sure you have disconnected the internet on the docker host (else it will auto update and may break the container),
and proceed with the offline mode setup.  
After the initial setup, got to console settings and disable auto update of the console and applications.  
The auto-update does not work and may break the container.

You can now proceed to add cameras to Protect.

## Logs

You can check logs using `docker compose logs -f` and files inside container at `/var/log`.  
Inside the container you can check logs using `journalctl -f`.  
`unifi-protect` logs are at `/srv/unifi-protect/logs`  
`unifi-core` logs are at `/data/unifi-core/logs`

## Issues running Systemd inside Docker

If you're getting the following error or any `systemd` error when starting container:  
Also check logs on host when starting container.
```
Failed to create /init.scope control group: Read-only file system
Failed to allocate manager object: Read-only file system
[!!!!!!] Failed to allocate manager object.
Exiting PID 1...
```

Boot the host system with kernel parameter `systemd.unified_cgroup_hierarchy=0`.

Also, no output when running `doker compose logs` means most likely it is due to the above error.

See: https://github.com/moby/moby/issues/42275

## Issues with remote access

> [!CAUTION]
> Make sure to update your network settings (**including your firewall rules**) to reflect the new interface name or you will lose internet connectivity. This is typically in `/etc/network/interfaces`.  
> If you are using NetworkManager service on host, then this does not apply, as your new interface will be configured using DHCP automatically, but your firewall rules may still need updating.

There is a known issue that remote access to your UNVR (via the Ubnt cloud) will not work with the console unless the primary network interface is named `enp0s2`. To achieve this, **on your host machine** create the file `/etc/systemd/network/98-enp0s2.link` with the content below, replacing `xx:xx:xx:xx:xx:xx` with your actual MAC address.

```
[Match]
MACAddress=xx:xx:xx:xx:xx:xx

[Link]
Name=enp0s2
```

**Make sure to update your network settings and your firewall rules to reflect the new interface name.**  
To apply the settings, run `sudo update-initramfs -u` and reboot your host machine.

## RTSP

RTSP streams from Protect are available under camera settings > Advanced.  
Remove `?enableSrtp` from the end and change to rtsp (port 7447) `rtsp://host-ip:7447/camera-id`.

## Building

Use the `build.sh` script.  
This will download and extract the firmware packages from the latest version available for the `UNVR` from the official UniFi download source (https://fw-update.ubnt.com), inside a docker container.  
You can provide a custom `FW_URL` environment variable to download the firmware binary from a custom link.  
Set `DOCKER_IMAGE` environment variable to use a custom image tag.

## Acknowledgements

This project has been greatly inspired from below projects.

[markdegrootnl/unifi-protect-arm64](https://github.com/markdegrootnl/unifi-protect-arm64) - original project  
[Top-Cat/unifi-protect-arm64](https://github.com/Top-Cat/unifi-protect-arm64) - fork  
[kiwimato/unifi-protect-arm64](https://github.com/kiwimato/unifi-protect-arm64) - fork  
[snowsnoot/unifi-unvr-arm64](https://github.com/snowsnoot/unifi-unvr-arm64) - fork

## Disclaimer

This Docker image is not associated with UniFi and/or Ubiquiti in any way.  
We do not distribute any third party software and only use packages that are freely available on the internet.
