# UniFi Protect UNVR Docker container for arm64

<a href="https://www.buymeacoffee.com/dciancu" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 42px !important;width: 151.9px !important;" ></a>

Run UniFi Protect UNVR in Docker on ARM64 hardware.

> [!IMPORTANT]
> Disconnect the docker host from the internet during the initial console setup, else it will auto update and may
> break the container.  
> Also remember to disable auto update of the console and applications in the console settings.  
> Make sure you have read the below sections on [Issues running systemd inside docker](#issues-running-systemd-inside-docker) and [Issues with remote access](#issues-with-remote-access).  
> Protect requires at least 4 GB RAM in order to boot and run correctly.  
> It is recommended to only run Protect with no other services/images when running on limited hardware (like Raspberry Pi).  
> If running inside a VM, make sure to bridge its net adapter or forward ports from host to the VM.  
> For macOS use `docker-compose.macos.yml`.

> [!TIP]
> Works on Raspberry Pi (tested with Pi 4 model B 4GB on Debian 12 Bookworm).  
> Protect 5.0 added support for third-party cameras via ONVIF, [see here](https://help.ui.com/hc/en-us/articles/26301104828439-Third-Party-Cameras-in-UniFi-Protect).

## Usage

You need to build the image using the `build.sh` script (see [Building](#building) section for details).  
This repo doesn't have prebuilt images available. This is to prevent redistribution of Ubiquiti's intelectual property.

Run the container using `docker compose` with the provided `docker-compose.yml`.  
**Make sure you have read the below sections on [Issues running systemd inside docker](#issues-running-systemd-inside-docker) and [Issues with remote access](#issues-with-remote-access).**

For the latest features and fixes always use the latest version.  
Some cameras may not adopt/work properly if Protect version is not new enough or the storage capacity is not 100 GB at least.  

## Building

Use the `build.sh` script.  
This will download and extract the firmware packages from the latest version available for the `UNVR` from the official UniFi download source (https://fw-update.ubnt.com) and then build Protect, all inside a docker containers.

Environment variables:
- Set `DOCKER_IMAGE` when building Protect to use a custom image tag.
- Set `BUILD_STABLE` when building Protect to build `stable` image - uses Protect version packaged in UNVR firmware.
- Set `BUILD_EDGE` when building Protect to build `edge` image - uses latest Protect version.
- Set `BUILD_TAG_VERSION` when building Protect to tag images with Protect version.
- Set `BUILD_PRUNE` when building Protect to delete ALL images and prune build cache.
- Set `BUILD_TEST` when building Protect to build test images.
- Set `FW_URL` when building firmware to download the firmware binary from a custom link.
- Set `FW_EDGE` when building firmware to download the latest firmware, instead of the supported repo firmware.
- Set `FW_UNSTABLE` when building firmware to download the latest version, skipping the stable flag.
- Set `FW_ALL_DEBS` when building firmware to extract and save all packages.

### Updates

> [!WARNING]
> Maintain regular backups of the host running Protect and its data and always make backups before updating.

Use `docker compose pull` followed by `docker compose up -d`.  
Protect should take care of migrating itself to a new version automatically (cameras firmware will also auto-update).  
**Never downgrade versions as this may break Protect.**

When Protect updates to a new version, this could introduce new firmware for the cameras, which will start updating.  
The camera firmware update could potentially make the camera no longer work with previous versions of Protect.  
Generally, camera firmware is stable, but should issues occur please note that downgrading camera firmware is very hard or not possible sometimes.

### Config

Create a new `docker-compose.override.yml` file and adjust below content for your configuration:
```
services:
  unifi-protect:
    image: dciancu/unifi-protect-unvr-docker-arm64:v5 # change tag here to use a different version
    environment:
      - STORAGE_DISK=/dev/sda
# If needed to mount device inside container.
#    devices:
#      - /dev/sda:/dev/sda
# Set DEBUG mode to enable all debug options below.
#      - DEBUG=true
# Set DEBUG_STORAGE to enable storage disk operations logging.
#      - DEBUG_STORAGE=true
# Set DEBUG_UNIFI_CORE to enable unifi-core debug log level.
#      - DEBUG_UNIFI_CORE=true
```
`STORAGE_DISK` should point to your disk holding the `storage` folder volume (see `docker-compose.yml`). **Make sure you have access to the device inside the container**, or mount it using `devices` key in `docker-compose.override.yml`.  
Protect video is at `/srv` volume inside container.

### macOS

Use `docker-compose.macos.yml`.
```
docker compose -f docker-compose.macos.yml -f docker-compose.override.yml up -d
```

Remote access via the cloud does not work with Docker on macOS, see https://github.com/dciancu/unifi-protect-unvr-docker-arm64/issues/25.  
Use a Debian VM instead (try with [UTM](https://mac.getutm.app/), it is open source).

### Network

> [!IMPORTANT]
> Protect requires `IPv6` enabled (even if blocked by firewall or not routed) and make sure ports used by Protect are not in use by other services/images (`80`, `443` etc.).  

Real UNVR has 2 network interfaces (`enp0s1` and `enp0s2`), if you mask your real network interface with `enp0s2` (see [Issues with remote access](#issues-with-remote-access)), then you only need to add `enp0s1`.  
For Debian, Ubuntu and other alike you can add a dummy interface with `ip link add enp0s1 type dummy`, and to be persistent across reboots, add to host network config at `/etc/network/interfaces`:
```
auto enp0s1
iface enp0s1 inet manual
    pre-up ip link add enp0s1 type dummy
    post-down ip link del enp0s1
```
Although this may not be needed and Protect may work and not give errors, the `ubnt-systool` network speed info will return an error when queried by Protect. It is not yet clear how or if this error influences Protect.  
This further helps mimic the UNVR hardware which Protect expects to be running on.

## Setup

> [!IMPORTANT]
> Protect requires at least 4 GB RAM in order to boot and run correctly.  

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
`unifi-protect` logs are at `/srv/unifi-protect/logs`.  
`unifi-core` logs are at `/data/unifi-core/logs`.  
If `DEBUG_STORAGE` is enabled, logs are at `/var/log/storage_disk_debug.log`.

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

> [!NOTE]
> Remote access via the cloud does not work with Docker on macOS (use a Debian VM instead).

There is a known issue that remote access to your UNVR via the cloud will not work with the console unless the primary network interface is named `enp0s2`. To achieve this, **on your host machine** create the file `/etc/systemd/network/98-enp0s2.link` with the content below, replacing `xx:xx:xx:xx:xx:xx` with your actual MAC address.

```
[Match]
MACAddress=xx:xx:xx:xx:xx:xx

[Link]
Name=enp0s2
```

**Make sure to update your network settings and your firewall rules to reflect the new interface name.**  
To apply the settings, run `sudo update-initramfs -u` and reboot your host machine.

I have also discovered that **direct remote access via the app** (without remote access enabled via Ubnt cloud, or being signed to UI account in the app) requires Protect to have access to `https://static.ui.com` in order to download MAC fingerprints, else you will run into a connection failed issue and will have to hit try again button a few times before you can connect directly and also your console may be displayed offline in the app. So for direct remote access to work correctly in the app, make sure Protect can access `https://static.ui.com`.

## RTSP

RTSP streams from Protect are available under camera settings > Advanced.  
Remove `?enableSrtp` from the end and change to rtsp (port 7447) `rtsp://host-ip:7447/camera-id`.

## Acknowledgements

This project has been greatly inspired from below projects.

[markdegrootnl/unifi-protect-arm64](https://github.com/markdegrootnl/unifi-protect-arm64) - original project  
[Top-Cat/unifi-protect-arm64](https://github.com/Top-Cat/unifi-protect-arm64) - fork  
[kiwimato/unifi-protect-arm64](https://github.com/kiwimato/unifi-protect-arm64) - fork  
[snowsnoot/unifi-unvr-arm64](https://github.com/snowsnoot/unifi-unvr-arm64) - fork

## Disclaimer

This is an experimental project. I do not take responsibility for anything regarding the use or misuse of the contents of this repository.  
By using this repo you accept all risk associated with it and releasing all parties from any liability associated with this software.

This Docker image is not associated with UniFi and/or Ubiquiti in any way.  
We do not distribute any third party software and only use packages that are freely available on the internet.
