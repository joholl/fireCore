#!/bin/bash


make build/rootfs-piCore-12.0.cpio
# cpio-extract as sudo
sudo make build/rootfs-piCore-12.0_cpio/opt/bootlocal.sh

# debug
#sudo sed -i 's_#!/bin/sh_#!/bin/sh\nset -x_g' build/rootfs-piCore-12.0_cpio/opt/bootlocal.sh







make build/overlay/tmp/builtin/optional/openssh.tcz
make build/overlay/tmp/builtin/optional/openssl.tcz
make build/overlay/tmp/builtin/optional/w1-5.4.51-piCore-v7.tcz
make build/overlay/tmp/builtin/optional/python3.8.tcz
make build/overlay/tmp/builtin/optional/python3.8-pip.tcz
make build/overlay/tmp/builtin/optional/python3.8-wheel.tcz
make build/overlay/tmp/builtin/optional/python3.8-rpi-gpio.tcz







for f in build/overlay/tmp/builtin/optional/*; do
    sudo unsquashfs -f -d build/rootfs-piCore-12.0_cpio/ $f
done

sudo chroot build/rootfs-piCore-12.0_cpio/ /bin/sh -c "
echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
/usr/local/tce.installed/python3.8  # TODO
LD_LIBRARY_PATH=/usr/local/lib python3 -m pip install uvicorn fastapi
LD_LIBRARY_PATH=/usr/local/lib /usr/local/etc/init.d/openssh start
"



# pack:  build/rootfs-piCore-12.0_cpio  ->  build/rootfs-piCore-12.0.cpio
sudo rm build/rootfs-piCore-12.0.cpio build/piCore-12.0_img1/rootfs-piCore-12.0.gz

cd build/rootfs-piCore-12.0_cpio; find . | sudo cpio --create --format newc --file ../rootfs-piCore-12.0.cpio; cd ../.. #--owner='1001:50'
gzip --recursive -2 build/rootfs-piCore-12.0.cpio --to-stdout > build/piCore-12.0_img1/rootfs-piCore-12.0.gz # -2

sudo rm -rf build/rootfs-piCore-12.0_cpio build/rootfs-piCore-12.0.cpio






# cpio-extract as sudo
sudo make build/rootfs-piCore-12.0_cpio/opt/bootlocal.sh





#make build/overlay/opt/boot.sh
# debug
#sudo sed -i 's_#!/bin/sh_#!/bin/sh\nset -x_g' build/overlay/opt/boot.sh





make deploy







