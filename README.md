# UniFi Protect UNVR Docker container for arm64

Run UniFi Protect UNVR in Docker on ARM64 hardware.

## Usage

Run the container using `docker compose` with the provided `docker-compose.yml`.  
Make sure you have read the below section on [Issues running systemd inside docker](#issues-running-systemd-inside-docker).

There is not output to `stdout`, and thus the `docker logs` of the container are empty.  
You can check logs inside the container using `journalctl -f` and files in `/var/log`.

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
