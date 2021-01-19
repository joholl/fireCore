#!/bin/bash

set -e

# Extract CPIO/GZ into directory (if $2 is given) or to $PWD
function extract_gz {
    local src="${1}"
    if [ ${#} -eq 3 ]; then
        local dest="${2}"
	    mkdir -p "${dest}"
        echo "Extracting gz archive ${src} to ${dest}..."
        if [ ! -d ${dest} ]; then
            gzip --decompress --keep "${src}" # TODO into dir
	else
            echo "Skipping because exists already: ${dest}"
	fi
    else
        echo "Extracting gz archive ${src}..."
        gzip --decompress --keep "${src}"
    fi
}

# Extract CPIO into directory
function extract_cpio {
    local src="${1}"
    local dest="${2}"
    echo "Extracting cpio archive ${src} to ${dest}..."
    if [ ! -d "${dest}" ]; then
        mkdir -p "${dest}"
        cpio --extract --file "${src}" --make-directories --preserve-modification-time --directory "${dest}"  || true
    else
        echo "Skipping because exists already: ${dest}"
    fi
}

# Extract CPIO/GZ into directory. Assumes cpio name is gz name without suffix.
function extract_gz_cpio {
    local src="${1}"
    local dest="${2}"
    extract_gz "${src}"
    extract_cpio "${src%.gz}" "${dest}"
}

# Create CPIO archive from directory $1
function create_cpio {
    echo "Creating cpio archive ${1} into ${2}..."
    local src="${1}"
    local dest="$(realpath ${2})"
    pushd ${src}
    find . | cpio --create --owner=1001:50 --format newc --file "${dest}" # tc:staff
    popd
}

# Create GZ archive from a file
function create_gz {
    local src="${1}"
    local dest="${2}"
    echo "Creating gz archive ${src} into ${dest}..."
    gzip --recursive "${src}" --to-stdout > ${dest}
}

# Create CPIO/GZ archive from file or directory. CPIO archive name is ${2%.gz}.
function create_cpio_gz {
    local src="${1}"
    local dest="${2}"
    local cpio="cpio/$(basename ${dest%.gz})"
    mkdir -p "$(dirname "${cpio}")"
    create_cpio "${src}" "${cpio}"
    create_gz  "${cpio}" "${dest}"
}

# Copy latest piCore image
# NOTE: choose latest version here!
picore_version_major=12
picore_version_minor=0
picore=piCore-${picore_version_major}.${picore_version_minor}
picore_zip=${picore}.zip
echo "Downloading ${picore_zip}..."
wget --no-clobber http://tinycorelinux.net/${picore_version_major}.x/armv6/releases/RPi/${picore_zip}

# Unzip image
echo "Extracting ${picore_zip}..."
unzip -n ${picore_zip}
picore_img=${picore}.img
echo

# Inspect partitions on image
echo "Inspecting Image ${picore_img}..."
fdisk -l ${picore_img}
# TODO extrace these numbers from fdisk stdout or use losetup --find --show <...>.img
img_sector_len=512
img_boot_start=8192
img_boot_sectors=131072
img_tce_start=139264
echo

# Mount image
echo "Mounting partitions of ${picore_img}..."
mnt=mnt
mnt_boot=${mnt}/boot
mnt_tce=${mnt}/tce
mkdir -p ${mnt_boot} ${mnt_tce}
sudo mount -o loop,uid=$(id -u),gid=$(id -g),offset=$(($img_boot_start*$img_sector_len)),sizelimit=$(($img_boot_sectors*$img_sector_len)) ${picore_img} ${mnt_boot} || true
sudo mount -o loop,offset=$(($img_tce_start*$img_sector_len)) ${picore_img} ${mnt_tce} || true
sudo chmod 755 ${mnt_tce}
echo

# Extract rootfs
rootfs_gz=${mnt_boot}/rootfs-${picore}.gz
rootfs=rootfs
extract_gz_cpio ${rootfs_gz} ${rootfs}

# Extract kernel modules
modules_gz=${mnt_boot}/modules-5.4.51-piCore-v7.gz
modules=modules
extract_gz_cpio ${modules_gz} ${modules}

# Create and register overlay
autoinstall=autoinstall
tce="${autoinstall}/tmp/builtin"
optional="${tce}/optional"
mkdir -p "${optional}"
cp "${mnt_tce}/tce/optional/openssh.tcz" "${mnt_tce}/tce/optional/openssl.tcz" "${optional}" # TODO fetch via wget?
echo "openssh.tcz" > "${tce}/onboot.lst"
echo "openssl.tcz" >> "${tce}/onboot.lst"
tce_gz="${mnt_boot}/builtin.gz"
create_cpio_gz "${autoinstall}" "${tce_gz}"
echo


echo "Original TCE: Register"
sed -i "s/\(initramfs [^ ]*\)/\1,$(basename "${tce_gz}")/g" ${mnt_boot}/config.txt
echo "Done"
echo

# Extract overlay (to check)
tce=builtin
extract_gz_cpio "${tce_gz}" "builtin"


# Own Overlay
#mkdir tce
#wget -P tce http://tinycorelinux.net/12.x/armv6/tcz/openssh.tcz


# Copy to TFTP server
echo "Copy to TFTP Server"
sudo mkdir -p /tftpboot
sudo chown pi:pi /tftpboot
rsync -xa --progress mnt/boot/ /tftpboot/
echo
