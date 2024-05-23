# UniFi Protect UNVR Docker container for arm64

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/F8zvFL89rXf6pgQo3twuVc/5tkZtrshQpSz4fo3k8M7ZZ/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/F8zvFL89rXf6pgQo3twuVc/5tkZtrshQpSz4fo3k8M7ZZ/tree/main)

Run UniFi Protect UNVR in Docker on ARM64 hardware.

> [!IMPORTANT]  
> Disconnect the docker host from the internet during the initial console setup, else it will auto update and may
> break the container.  
> Also remember to disable auto update of the console and applications in the console settings.

## Usage

Docker Hub Image: [dciancu/unifi-protect-unvr-docker-arm64](https://hub.docker.com/r/dciancu/unifi-protect-unvr-docker-arm64)  
Tags:
- **stable - recommended**, uses unifi-protect version packaged in UNVR firmware
- edge - uses latest unifi-protect version (may not always work)
- specific version - uses unifi-protect version packaged in UNVR firmware (this is an alias for each stable release)

Run the container using `docker compose` with the provided `docker-compose.yml`.  
Make sure you have read the below section on [Issues running systemd inside docker](#issues-running-systemd-inside-docker).

Create a new `docker-compose.override.yml` file and adjust below content for your configuration:
```
services:
  unifi-protect:
    environment:
      - STORAGE_DISK=/dev/sda
      - TZ=UTC
```
The `STORAGE_DISK` should point to your disk holding the storage folder volume (see `docker-compose.yml`).  
The `TZ` sets the timezone inside the container and is used by Protect for camera and events timestamp.  
Valid timezones inside the container are under `/usr/share/zoneinfo`.

There is not output to `stdout`, and thus the `docker logs` of the container are empty.  
You can check logs inside the container using `journalctl -f` and files in `/var/log`.

## Setup

When you run the image for the first time, you have to go through the initial console setup, find the host IP address and
navigate to `http://host-ip`.  
Make sure you have disconnected the internet on the docker host (else it will auto update and may break the container),
and proceed with the offline mode setup.  
After the initial setup, got to console settings and disable auto update of the console and applications.  
The auto-update does not work and may break the container.

You can now proceed to add cameras to Protect.

### Issues running Systemd inside Docker

If you're getting the following error (or any systemd error):  
Also check logs on the host when starting container.
```
Failed to create /init.scope control group: Read-only file system
Failed to allocate manager object: Read-only file system
[!!!!!!] Failed to allocate manager object.
Exiting PID 1...
```

Boot the system with kernel parameter `systemd.unified_cgroup_hierarchy=0`

See: https://github.com/moby/moby/issues/42275

## Building

Use the `build.sh` script.  
This will download and extract the firmware packages from the latest version available for the `UNVR` from the official UniFi download source (https://fw-update.ubnt.com), inside a docker container.
You can provide a custom `FW_URL` environment variable to download the firmware binary from a custom link.

## Issues with remote access

There is a known issue that remote access to your UNVR (via the Ubnt cloud) will not work with the console unless the primary network interface is named `enp0s2`. To achieve this, **on your host machine** create the file `/etc/systemd/network/98-enp0s2.link` with the content below, replacing `xx:xx:xx:xx:xx:xx` with your actual MAC address.

```
[Match]
MACAddress=xx:xx:xx:xx:xx:xx

[Link]
Name=enp0s2
```

Make sure to update your network settings to reflect the new interface name.  
To apply the settings, run `sudo update-initramfs -u` and reboot your host machine.

## Acknowledgements

This project has been greatly inspired from the below projects.

[markdegrootnl/unifi-protect-arm64](https://github.com/markdegrootnl/unifi-protect-arm64) - original project  
[Top-Cat/unifi-protect-arm64](https://github.com/Top-Cat/unifi-protect-arm64) - fork  
[kiwimato/unifi-protect-arm64](https://github.com/kiwimato/unifi-protect-arm64) - fork  
[snowsnoot/unifi-unvr-arm64](https://github.com/snowsnoot/unifi-unvr-arm64) - fork

## Disclaimer

This Docker image is not associated with UniFi and/or Ubiquiti in any way.  
We do not distribute any third party software and only use packages that are freely available on the internet.
