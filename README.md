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
 * genisoimage (as a replacement for mkisofs as a part of cdrtools)
 * qemu-user-static

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
  * Raspberry Pi: **DHCP Discovery** (incl. Option 60 -> request PXE network
    boot)
  * DHCP Server (dnsmasq): **DHCP Offer** (incl. Option 66 -> TFTP Server IP)
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




# Network Boot

## Raspberry

* Pi: DHCP Discovery with option 60 to `ff:ff:ff:ff:ff:ff`
* OpenWrt: DHCP Offer with option 66
* ...

If DHCP Discovery is not sent, ensure enough power (unplug peripherals). If
issue persists, boot a valid image with `context.txt` as above and reboot. Then
shutdown and retry without SD card.

To capture packages on OpenWrt, use the following, where `B8:27:EB:3F:D6:0B` is
the Raspberry Pi MAC address.

```
ssh root@192.168.1.1 tcpdump -i br-lan -w- ether host B8:27:EB:3F:D6:0B | sudo wireshark -k -i -
```

If in doubt, connect the Raspberry and a laptop running wireshark onto a dumb
switch. Since the DHCP Discovery is a broadcast, it should be picked up no
matter what.

## OpenWrt

Network -> Interfaces -> TFT Settings:

* TFTP Settings: `/mnt/sda1` (where usb is mounted)
* Network boot image: `bootcode.bin`

This sets DHCP Offer option 67 to `bootcode.bin` but the client expects the TFTP
server IP (not domain name!) in option 66. So we ssh into the router and add in
`/etc/config/dhcp` to the section `dnsmasq` (which provides the DHCP service for
IPv4) the following line:

```
    option dhcp_option '66,192.168.1.1'
```

On a side note, this could also be done by using the universal configuration
interface `uci`.

Lastly, we restart the dns/dhcp service:

```
service dnsmasq restart
```









# TinyCore

The Linux distribution, that is ultimately downloaded and booted, is
[TinyCore](http://tinycorelinux.net/corebook.pdf). Its Raspberry Pi version is
called PiCore.

Since after booting, the system runs without an SD card, it runs in default mode. That is,
everything is copied to RAM and never written on any storage medium. A reboot
will result in a fresh image.

Additionally, no package is downloaded and installed during normal operation.
Instead, all packages are preinstalled on the initramfs image
`tftp/TODO` and loaded automatically at boot. The same applies
to every custom script/application which were added to piCore.

Remastering is implemented as a Makefile, so if you are not interested in the
details, just call:

```
make all
```

# Remastering

Remastering is complex. But it pays off (more on that later). Here is my effort
of explaining the process. In short: we basically need to mount a fully
functional piCore rootfs, chroot into it and install some packages... and then
create an image out of that. Easy peasy.

I'll spare you the command line stuff. This should give only give a high level
overview. For details, just have a look into the Makefile.

We download [piCore-12.0.zip](http://tinycorelinux.net/12.x/armv7/releases/RPi/piCore-12.0.zip).
It contains the original boot image `piCore-12.0.img`, which itself contains two partitions.
These are extracted to `build/piCore-12.0.img.0` and `build/piCore-12.0.img.1`.

```
+-----------------------------------------------+
| Boot image:          piCore-12.0.img          |
|   +-------------------------------------------+
|   | Boot partition:  build/piCore-12.0.img.0  |
|   +-------------------------------------------+
|   | TCE partition:   build/piCore-12.0.img.1  |
+---+-------------------------------------------+
```

The boot partition has all files neccessary for booting (kernel, rootfs, ...)
and the TinyCore Extension (TCE) partition contains basic packages like openssh.
Both images are mounted to `build/mnt/`.

Let's have a closer look at the boot partition. Most importantly, it contains
two CPIO archives, which are mounted to `/` at boot time.

```
+--------------------------------------------------------------------------------------------+
| Boot partition:      build/mnt/boot/                                                       |
|   +----------------------------------------------------------------------------------------+
|   | Kernel modules:  modules-5.4.51-piCore-v7.gz (contains modules-5.4.51-piCore-v7.cpio)  |
|   +----------------------------------------------------------------------------------------+
|   | rootfs:          rootfs-piCore-12.0.gz       (contains rootfs-piCore-12.0.cpio)        |
+---+----------------------------------------------------------------------------------------+
```

## Mounting the rootfs

As I have mentioned, we need to recreate the rootfs. To this end, we mount a lot
of stuff together to a single rootfs. Bear with me, all of this will make sense
shortly ;)

```
+-----------------------------------------------------------+
| Mounted into build/rootfs (bottom is mounted first):      |
|   +-------------------------------------------------------+
|   | < Overlay >      build/overlay                        |
|   +-------------------------------------------------------+
|   | Packages TCE:    build/mnt/tce                        |
|   +-------------------------------------------------------+
|   | Kernel modules:  build/modules-5.4.51-piCore-v7_cpio  |
|   +-------------------------------------------------------+
|   | rootfs:          build/rootfs-piCore-12.0_cpio        |
+---+-------------------------------------------------------+
```

As can be seen here, we mount the rootfs itself, kernel modules and the basic
packages distributed by TinyCore. Since it is mounted as an *overlay*, any
changes written to `build/rootfs` will end up in `build/overlay`.

We are not just done with the mount magic, yet. Lastly, we have to mount some
kernel interfaces needed to actually chroot into the rootfs. Namely, we mount
our host system `/proc`, `/sys` and `/sys/fs/binfmt_misc` file systems into the
rootfs.

```
+--------------------------------------------------------------------------------------------------+
| Mounted into build/rootfs                                                                        |
|   +----------------------------------------------------------------------------------------------+
|   | < Overlay >      build/overlay                                                               |
|   +----------------------------------------------------------------------------------------------+
|   | binfmt_misc:     /sys/fs/binfmt_misc (mounted to build/mnt/rootfs/proc/sys/fs/binfmt_misc/)  |
|   +----------------------------------------------------------------------------------------------+
|   | sys:             /sys                                                                        |
|   +----------------------------------------------------------------------------------------------+
|   | proc:            /proc                                                                       |
|   +----------------------------------------------------------------------------------------------+
|   | Packages TCE:    build/mnt/tce                                                               |
|   +----------------------------------------------------------------------------------------------+
|   | Kernel modules:  build/modules-5.4.51-piCore-v7_cpio                                         |
|   +----------------------------------------------------------------------------------------------+
|   | rootfs:          build/rootfs-piCore-12.0_cpio                                               |
+---+----------------------------------------------------------------------------------------------+
```

## Installing packages = TinyCore Extensions (TCEs)
This part is easy. We just download the packages from the
[mirror](http://tinycorelinux.net/12.x/armv7/tcz/) and unsquash them to
`build/rootfs`. Note that some packages put init routines to
`/usr/local/tce.installed` that run on first boot. For example, openssh needs to
create RSA keys. We take care of that inside the chroot, later.

## Preparing chroot

Ok, now we can finally mount into the rootfs, right? Well, that would be right
if our host system had an ARMv7 processor. Since we run on a x86 machine, we
cannot execute a single binary in there. However, there is a solution to this:
QEMU lets run ARM binaries easily.

We just need to install
[qemu-arm-static](build/mnt/rootfs/usr/bin/qemu-arm-static) into
`build/mnt/rootfs/usr/bin`. Inside the rootfs, we can then call `qemu-arm-static
<binary>`.

Even better, by writing some funky bytes to
`build/mnt/rootfs/proc/sys/fs/binfmt_misc/register`, we can register QEMU as
interpreter for ARM binaries. For that kind of black magic, see the Makefile.
This let's us work with the piCore rootfs on our host machine just as if we were
on our Raspberry Pi, how awesome is that?

## chroot

To initiallize all unsquashes TCEs, we execute every binary inside
`/usr/local/tce.installed`.

Now comes the crazy part. We can simply install python packages for our ARM
rootfs on our host machine... using the ARM python binary!

```
python3 -m pip install $(shell cat $(PYTHON_PACKAGES_LIST_SRC));
```

## Deploying our app

Now that we have all packages installed on our rootfs, it is time to deploy our
own application. Basically we copy a bunch of files directly into the overlay
directory.

 * bootscript, called at the end of the boot sequence (non-blocking), calls `boot.sh`
   * src: `build/rootfs-piCore-12.0_cpio/opt/bootlocal.sh`
   * dst: `build/overlay/opt/bootlocal.sh`
 * custom script `boot.sh`, starts the python app
   * src: `src/boot.sh`
   * dst: `build/overlay/opt/boot.sh`
 * python app
   * src: `src/app/server.py`
   * dst: `build/overlay/tmp/app/server.py`

Done. Now all we need to do is re-package that overlay into a CPIO archive and
create a new boot image.

## Packaging the overlay

We package the overlay into a CPIO archive inside a gzip package:
`build/overlay.gz`. Then, we instruct our raspberry to mount that on top of the
rootfs by adding it to the initramfs list in `/boot/config.txt`:

```
initramfs rootfs-piCore-12.0.gz,modules-5.4.51-piCore-v7l.gz,overlay.gz followkernel
```

## Shipping

We have two options now, either we create an sd card image or we upload the
necessary files to the TFTP server

### SD card image

This is not implemented, yet. The TinyCore Cookbook uses genisoimage/mkisofs
(it's the same) to create their single-partition x86 TinyCore image.

In the Raspberry Pi world, one could either dd a hardware (or maybe emulated?)
sd card to a `.img` file or use `qemu-img`, as done by [pi-gen](https://github.com/RPi-Distro/pi-gen/blob/master/build.sh#L352).

Since we use an initramfs, we should only need a MS/DOS boot partition.

### TFTP

The Raspberry Pi will download the files needed, starting with `bootcode.bin`.
It is good practice to just copy the whole TinyCore boot partition onto the
server. Depending on the hardware, different kernels, device trees etc. will be
downloaded.

The only two changes to the upstream TinyCore is the `overlay.gz` and the
modified `config.txt` which instructs the Raspberry Pi to apply the overlay.
