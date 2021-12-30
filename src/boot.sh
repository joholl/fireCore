#!/bin/sh

# change password of user 'tc' to 'piCore'
sh -c "echo 'tc:piCore' | chpasswd"

# change hostname and re-advertise
# TODO start dhcp per init.d service (does not work unless interface is down?)
/etc/init.d/services/dhcp stop
sethostname bla
NETDEVICES="$(awk -F: '/eth.:|tr.:/{print $1}' /proc/net/dev 2>/dev/null)"  # eth0
for DEVICE in $NETDEVICES; do
    /sbin/udhcpc -b -i $DEVICE -x hostname:$(/bin/hostname) -p /var/run/udhcpc.$DEVICE.pid >/dev/null 2>&1 &
done

# load kernel modules
depmod && modprobe w1-gpio

# set timezone (via env variable), for values see https://oldwiki.archive.openwrt.org/doc/uci/system#time.zones
echo "TZ=CET-1CEST,M3.5.0,M10.5.0/3" > /etc/sysconfig/timezone

# run server
cd /tmp && PYTHONPATH=${PYTHONPATH}:src python3 -m app && cd
