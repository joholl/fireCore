# Dependencies

Make fireCore (remastered tinyCore)
 * make
 * wget
 * unzip
 * sfdisk
 * jq
 * mtools
 * gzip
 * cpio
 * squashfs-tools

fireCore python server
 * fastapi
 * uvicorn

DHCP proxy and TFTP server
 * dnsmasq

# Network Boot

[Network boot](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/net.md) is available on Raspberry Pi 3 B and later. That is, the Raspberry Pi can boot without an SD card via [PXE network boot](https://www.raspberrypi.org/documentation/hardware/raspberrypi/bootmodes/net_tutorial.md).

## Enabling on the Raspberry Pi

Network boot needs to be enabled once.

```bash
echo "program_usb_boot_mode=1" > /boot/config.txt
reboot
```

To sanity-check: line 17 should show `3020000a`:

```bash
vcgencmd otp_dump
```

## dnsmasq: DHCP Proxy and TFTP Server

The TFTP Server IP address can be published by the DHCP server itself or a
so-called DHCP proxy (i.e. a secondary host, here also called DHCP server). In
this project, dnsmaq is use both as a DHCP proxy and TFTP server.

Configuring is done via `/etc/dnsmasq.conf`:

```bash
port=0
interface=eth0
dhcp-range=172.16.1.0,proxy,255.255.255.0   # TODO can we avoid hardcoding the net address?
log-dhcp
enable-tftp
tftp-root=/tftpboot
pxe-service=0,"Raspberry Pi Boot"
```

## Packet Sequence



* DHCP
  * Raspberry Pi: **DHCP Discovery**
  * DHCP Server (dnsmasq): **DHCP Offer** (incl. Option 43 -> TFTP Server IP)
* ARP
  * Raspberry Pi: **ARP Request** (Who has TFTP Server IP?)
  * TFTP Server (dnsmasq): **ARP Reply** TFTP Server IP is at TFTP Server MAC
* TFTP
  * Raspberry Pi: **TFTP Read Request**: bootcode.bin
  * TFTP Server (dnsmasq): TFTP Data Packet (Block 1)
  * Raspberry Pi: TFTP Acknowledgement (Block 1)
  * TFTP Server (dnsmasq): TFTP Data Packet (Block 2)
  * ...

A failed network boot might be caused by an insufficient power supply. After the
first file `bootcode.bin` is downloaded, the Raspberry Pi might send further
DHCP requests, followed by ARP requests.

The next file to be downloaded (if available) is `<serial_no>/start.elf`. This
can be used to deploy different images to the respective hosts. The `serial_no`
is a 4-byte value shown via `cat /proc/cpuinfo | grep 'Serial'`. Additionally,
the three least significant bytes seem to be used as the least significant bytes
of the MAC address. This feature is not used, here.

# TinyCore

The Linux distribution, that is ultimately downloaded and booted, is
[TinyCore](http://tinycorelinux.net/corebook.pdf). Its Raspberry Pi version is
called PiCore.

Since the system runs without an SD card, it runs in default mode. That is,
everything is copied to RAM and never written on any storage medium. A reboot
will result in a fresh image.

Additionally, no package is downloaded and installed during normal operation.
Instead, all packages are included on the initramfs image
`/boot/rootfs-piCore-12.0.gz` and loaded automatically at boot. The same applies
to every custom script/application which were added to piCore.

## Remastering

Customizing the boot image is called remastering.








