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

# load one-wire driver
sudo modprobe w1-therm

# install python packages using wheel
python3 -m pip install /tmp/wheel/optional/*

# run server
cd /tmp/app && python3 server.py && cd