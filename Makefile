# settings
PICORE_VERSION_MAJOR = 12
PICORE_VERSION_MINOR =  0

PICORE = piCore-$(PICORE_VERSION_MAJOR).$(PICORE_VERSION_MINOR)

# general directories
BUILD_DIR = build
OVERLAY_DIR = $(BUILD_DIR)/overlay
BOOT_DIR = boot
MNT_DIR = $(BUILD_DIR)/mnt

# suffixes
DIR = .dir
MNT = .mnt

# TODO RM
DIRSTAMP = .dirstamp

MAKEFILE_DIR=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))

################# boot partition #################
PICORE_ZIP = $(BUILD_DIR)/$(PICORE).zip
PICORE_UNZIP_DIR = $(BUILD_DIR)/$(PICORE)_unzip
PICORE_UNZIP_FILES = $(PICORE_UNZIP_DIR)/$(PICORE).img
# MS/DOS partition table + boot partition + tce partition
PICORE_IMG = $(PICORE_UNZIP_DIR)/$(PICORE).img
# image 0: boot FAT partition, incl. kernel, rootfs, kernel modules
PICORE_PART_BOOT = $(BUILD_DIR)/$(PICORE).img.0
# image 1: tce ext4 partition, incl. basic packages
PICORE_PART_TCE = $(BUILD_DIR)/$(PICORE).img.1
PICORE_PARTITIONS = $(PICORE_PART_BOOT) $(PICORE_PART_TCE)
# mount points
PICORE_MNT_BOOT = $(MNT_DIR)/boot
PICORE_MNT_TCE = $(MNT_DIR)/tce


#PICORE_MNT_BOOT_FILES = $(addprefix $(PICORE_MNT_BOOT)/,modules-5.4.51-piCore-v7.gz rootfs-$(PICORE).gz)
# $(addsuffix _cpio,$(basename modules-5.4.51-piCore-v7.gz rootfs-$(PICORE).gz)))
#PICORE_MNT_TCE_FILES = $(PICORE_MNT_TCE)/tce/onboot.lst






# boot partition (FAT partition)
PICORE_IMG1 = $(BUILD_DIR)/$(PICORE).img1
# boot partition (extracted)
PICORE_IMG1_DIR = $(BUILD_DIR)/$(PICORE)_img1
PICORE_IMG1_FILES = $(addprefix $(PICORE_IMG1_DIR)/,bootcode.bin config.txt start.elf fixup.dat rootfs-piCore-12.0.gz modules-5.4.51-piCore-v7.gz bcm2710-rpi-3-b.dtb cmdline.txt kernel5451v7.img overlays)

################# rootfs + rootfs remastered #################
ROOTFS_CPIO_DIR = $(BUILD_DIR)/rootfs-$(PICORE)_cpio
ROOTFS_REMASTERED_CPIO_DIR = $(BUILD_DIR)/rootfs-piCore-12.0_remastered_cpio
ROOTFS_REMASTERED_CPIO_FILES = $(ROOTFS_REMASTERED_CPIO_DIR)/opt/bootlocal.sh

################# overlay #################
# TODO
PACKAGES_LIST_SRC = src/packages.lst
PACKAGES_DIR = $(BUILD_DIR)/packages
PACKAGES = $(addprefix $(PACKAGES_DIR)/,$(shell grep -v '^#' $(PACKAGES_LIST_SRC)))

PYTHON_PACKAGES_LIST_SRC = src/python-packages.lst

OVERLAY_BOOTSCRIPT = $(OVERLAY_DIR)/opt/boot.sh
OVERLAY_BOOTSCRIPT_SRC = src/boot.sh

OVERLAY_BOOTLOCAL = $(OVERLAY_DIR)/opt/bootlocal.sh

OVERLAY_APP_DIR = $(OVERLAY_DIR)/tmp/app
OVERLAY_APP_SRC = src/app
OVERLAY_APP = $(subst $(OVERLAY_APP_SRC),$(OVERLAY_APP_DIR),$(shell find $(OVERLAY_APP_SRC) -name '*.py'))

OVERLAY_FILES = $(OVERLAY_BOOTSCRIPT) $(OVERLAY_BOOTLOCAL) $(OVERLAY_APP)

OVERLAY_CPIO = $(BUILD_DIR)/overlay.cpio

OVERLAY_GZ = $(BUILD_DIR)/overlay.gz

# TODO remove touch and dirstamp leftover code?

# TODO add variable for arch, switch armv7l instead of armv7?

################# remastered #################
PICORE_REMASTERED_DIR = $(BOOT_DIR)
PICORE_REMASTERED_FILES = $(addprefix $(PICORE_REMASTERED_DIR)/,$(notdir $(PICORE_IMG1_FILES) $(OVERLAY_GZ)))

################# TODO #################
CONFIG_TXT_APPEND_SRC = src/config.txt.append
CMDLINE_TXT_SRC = src/cmdline.txt

################# debug #################
MODULES_CPIO_DIR = $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio
OVERLAY_CPIO_DIR = $(BUILD_DIR)/overlay_cpio

################# deploy #################
TFTP_DIR = tftpboot
TFTP_FILES = $(addprefix $(TFTP_DIR)/,$(notdir $(PICORE_REMASTERED_FILES)))


# remastered tinyCore aka fireCore
# re-extract file system archives for debugging
PICORE_MODULES_CPIO_DIR = $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio
OVERLAY_CPIO_DIR = $(BUILD_DIR)/overlay_cpio

# TODO clean up these variables and harmonize naming
TFTPSERVER = $(BUILD_DIR)/tftpserver
space = $(subst ,, )






################# extract boot partition images #################
$(PICORE_ZIP):
	@printf "\n======================= Download piCore boot partition: $@ =======================\n"
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv7/releases/RPi/$(PICORE).zip

$(PICORE_UNZIP_FILES): $(PICORE_ZIP)
	@printf "\n======================= Unzip piCore boot partition: $@ =======================\n"
	mkdir -p $(dir $@)
	unzip -d $(dir $@) $?

# TODO move this? make this more generic? Have this used by target $(PICORE_IMG1)
$(BUILD_DIR)/$(PICORE).img.%: $(PICORE_UNZIP_DIR)/$(PICORE).img
	@printf "\n======================= Extract partition from piCore img: $@ =======================\n"
	mkdir -p $(dir $@)
	dd if=$? of=$@ skip=$(shell sfdisk --json $? | jq ".partitiontable.partitions[$(subst .,,$(suffix $@))].start") count=$(shell sfdisk --json $? | jq ".partitiontable.partitions[$(subst .,,$(suffix $@))].size")


$(PICORE_MNT_BOOT)$(MNT): $(PICORE_PART_BOOT)
	@printf "\n======================= Mount piCore boot partition: $@ =======================\n"
	mkdir -p $(basename $@)
	sudo mount -t vfat -o ro $? $(basename $@)
	touch $@

################# mount tce partition #################
$(PICORE_MNT_TCE)$(MNT): $(PICORE_PART_TCE)
	@printf "\n======================= Mount TCE partition: $@ =======================\n"
	mkdir -p $(basename $@)
	sudo mount -o ro,noload $? $(basename $@)
	touch $@

################# mount partition images #################
# TODO via pattern rule?
build/mnt/boot/modules-5.4.51-piCore-v7.gz: $(PICORE_MNT_BOOT)$(MNT)
build/mnt/boot/rootfs-piCore-12.0.gz: $(PICORE_MNT_BOOT)$(MNT)

$(BUILD_DIR)/%.gz: $(PICORE_MNT_BOOT)/%.gz
	@printf "\n======================= Prepare CPIOs for boot partition: copy original: $@ =======================\n"
	cp $? $@

$(BUILD_DIR)/%.cpio: $(BUILD_DIR)/%.gz
	@printf "\n======================= Prepare CPIOs for boot partition: convert to CPIO $@ =======================\n"
	gzip --decompress --keep --to-stdout $? > $@

$(BUILD_DIR)/%_cpio$(DIR): $(BUILD_DIR)/%.cpio
	@printf "\n======================= Prepare CPIOs for boot partition: extract CPIO: $@ =======================\n"
	mkdir -p $(basename $@)
	sudo cpio --extract --make-directories --file $? --directory $(basename $@) || true
	touch $@

################# mount to rootfs, results are in overlay #################
# TODO make this (and any other mount target phony)
$(MNT_DIR)/rootfs$(MNT): $(PICORE_MNT_TCE)$(MNT) $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio$(DIR) $(BUILD_DIR)/rootfs-piCore-12.0_cpio$(DIR)
	@printf "\n======================= Mount piCore boot partition, modules and TCE as rootfs, changes are in overlay: $@ =======================\n"
	mkdir -p build/workdir build/overlay $(basename $@)
	sudo mount -t overlay overlay -o lowerdir=$(subst $(space),:,$(basename $?)),workdir=build/workdir,upperdir=build/overlay $(basename $@)
	touch $@

################# piCore packages #################
# PACKAGES:
# http://tinycorelinux.net/12.x/armv7/tcz/
%.tcz:
	@printf "\n======================= Download piCore package: $@ =======================\n"
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv7/tcz/$(notdir $@)


# ################# rootfs + rootfs remastered #################
ROOTFS_MNTs = $(MNT_DIR)/rootfs/proc/cpuinfo $(MNT_DIR)/rootfs/sys$(MNT) $(MNT_DIR)/rootfs/proc/sys/fs/binfmt_misc/status

$(MNT_DIR)/rootfs/proc/cpuinfo: $(MNT_DIR)/rootfs$(MNT)
	@printf "\n======================= Prepare qemu: mount host /proc to rootfs: $@ =======================\n"
	sudo mount -t proc /proc $(dir $@)

$(MNT_DIR)/rootfs/sys$(MNT): $(MNT_DIR)/rootfs$(MNT)
	@printf "\n======================= Prepare qemu: mount host /sys to rootfs: $@ =======================\n"
	mount | grep -oP '(?<= on )$(MAKEFILE_DIR)$(MNT_DIR)/rootfs/sys' || \
		sudo mount -t sysfs /sys $(MNT_DIR)/rootfs/sys
	sudo touch $@

$(MNT_DIR)/rootfs/proc/sys/fs/binfmt_misc/status: $(MNT_DIR)/rootfs/proc/cpuinfo $(MNT_DIR)/rootfs$(MNT)
	@printf "\n======================= Prepare qemu: mount host binfmt_misc to rootfs: $@ =======================\n"
	# TODO makefile if?
	if [ ! -f $@ ]; then \
		sudo mount -t binfmt_misc none $(dir $@); \
	fi
	sudo touch $@

$(MNT_DIR)/rootfs/usr/bin/qemu-arm-static:
	@printf "\n======================= Install qemu to rootfs: $@ =======================\n"
	sudo wget --output-document=$@ https://github.com/multiarch/qemu-user-static/releases/download/v5.2.0-2/qemu-arm-static
	sudo chmod 755 $@

# Install packages, generate ssh keys
# TODO use https://unix.stackexchange.com/questions/41889/how-can-i-chroot-into-a-filesystem-with-a-different-architechture
#   sudo wget --output-document=build/rootfs-piCore-12.0_remastered_cpio/usr/bin/qemu-arm-static https://github.com/multiarch/qemu-user-static/releases/download/v5.2.0-2/qemu-arm-static
#   sudo chmod 755 build/rootfs-piCore-12.0_remastered_cpio/usr/bin/qemu-arm-static
#   #sudo cp $(which qemu-arm) build/rootfs-piCore-12.0_remastered_cpio/usr/bin/
#   sudo chroot build/rootfs-piCore-12.0_remastered_cpio/ /usr/bin/qemu-arm-static /bin/sh
# TODO we need to install packages by unsquashing? solve the proc device thing?
$(MNT_DIR)/rootfs.done: $(MNT_DIR)/rootfs$(MNT) $(ROOTFS_MNTs) $(MNT_DIR)/rootfs/usr/bin/qemu-arm-static $(PACKAGES)
	@printf "\n======================= Qemu: install TCE packages and pip wheels $@ =======================\n"
	# extract packages into rootfs
	for pkg in $(PACKAGES); do \
		sudo unsquashfs -f -d $(basename $@) $$pkg; \
	done

	# set nameserver to enable pip downloads
	sudo cp /etc/resolv.conf $(basename $@)/etc/resolv.conf

	sudo chroot $(basename $@) /usr/bin/qemu-arm-static /bin/sh -c " \
		export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; \
		export LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib; \
		echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register; \
		find /usr/local/tce.installed -type f -exec {} \;; \
		python3 -m pip install $(shell grep -v '^#' $(PYTHON_PACKAGES_LIST_SRC)); \
		/usr/local/etc/init.d/openssh start; \
	"

	# # unmount (TODO is a target)
	# for mnt in $(shell mount | grep -oP '(?<= on )$(MAKEFILE_DIR)$(BUILD_DIR)\S*' | awk '{ print length, $$0 }' | sort -n -s -r | cut -d' ' -f2-); do \
	# 	echo "umount $$mnt..."; \
	# 	sudo umount -l "$$mnt"; \
	# done

	sudo touch $@






# ################# overlay #################
# boot.sh
$(OVERLAY_BOOTSCRIPT): $(OVERLAY_BOOTSCRIPT_SRC)
	@printf "\n======================= Copy custom boot script: $@ =======================\n"
	sudo install --mode 755 --owner=root --group=root -D $? $@

# bootlocal.sh
$(ROOTFS_CPIO_DIR)/opt/bootlocal.sh: $(ROOTFS_CPIO_DIR)$(DIR)
$(OVERLAY_BOOTLOCAL): $(ROOTFS_CPIO_DIR)/opt/bootlocal.sh
	@printf "\n======================= Copy bootlocal.sh (called by init): $@ =======================\n"
	sudo install --mode 755 --owner=root --group=root -D $< $@
	sudo sh -c "echo '/opt/boot.sh' >> $@"

# app
$(OVERLAY_APP_DIR)/%.py: $(OVERLAY_APP_SRC)/%.py
	@printf "\n======================= Copy app: $@ =======================\n"
	sudo install --mode 755 --owner=root --group=root -D $< $@

app:
	echo $(OVERLAY_APP)

# TODO also includes left-over files (e.g. packets)... pass OVERLAY_FILES with relative path?
# requires all of the above
$(OVERLAY_CPIO): $(OVERLAY_FILES) $(MNT_DIR)/rootfs.done
	@printf "\n======================= Create overlay CPIO archive: $@ =======================\n"
	# cd $(OVERLAY_DIR); find . | sudo cpio --create --owner='1001:50' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff
	cd $(OVERLAY_DIR); find . | sudo cpio --create --owner='0:0' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff

$(OVERLAY_GZ): $(OVERLAY_CPIO)
	@printf "\n======================= Create overlay GZ archive: $@ =======================\n"
	gzip --recursive $? --to-stdout > $@
	# Compressing overlay (optional)
	advdef -z3 $@

overlay: $(OVERLAY_GZ)








all: $(TFTPSERVER).tar
.DEFAULT_GOAL := all



# ################# testing #################
build/combined.gz: build/rootfs-piCore-12.0.gz build/overlay.gz
	cat $? > $@

# TODO prerequisites do not exist/result in corrupt image?
check: build/combined.gz build/mnt/boot/kernel5451v7.img build/mnt/boot/bcm2709-rpi-2-b.dtb
	sudo expect ./qemu-system.expect




################# PXE network boot files #################
$(TFTPSERVER)/overlay.gz: $(OVERLAY_GZ)
	@printf "\n======================= Copy overlay needed for PXE boot: $@ =======================\n"
	install -d $(TFTPSERVER) || true
	install -D $? $@
$(TFTPSERVER)/cmdline.txt: $(CMDLINE_TXT_SRC)
	@printf "\n======================= Copy kernel cmdline needed for PXE boot: $@ =======================\n"
	install -d $(TFTPSERVER) || true
	install -D $? $@
$(TFTPSERVER)/config.txt: $(CONFIG_TXT_APPEND_SRC) $(PICORE_MNT_BOOT)/config.txt
	@printf "\n======================= Build config.txt needed for PXE boot: $@ =======================\n"
	install -d $(TFTPSERVER) || true
	install -D $(PICORE_MNT_BOOT)/config.txt $@
	# modify config.txt
	sed -i "s/\(initramfs [^ ]*\)/\1,$(notdir $(OVERLAY_GZ))/g" $(TFTPSERVER)/config.txt
	echo "$(shell cat $(CONFIG_TXT_APPEND_SRC))" >> $(TFTPSERVER)/config.txt
tftpserver: $(PICORE_MNT_BOOT)$(MNT) $(TFTPSERVER)/overlay.gz $(TFTPSERVER)/config.txt $(TFTPSERVER)/cmdline.txt
	@printf "\n======================= Gather files needed for PXE boot =======================\n"
	rsync --archive --update --exclude=config.txt $(PICORE_MNT_BOOT)/ $(TFTPSERVER)


$(TFTPSERVER).tar: tftpserver
	@printf "\n======================= Archive all PXE boot files: $@ =======================\n"
	cd $(TFTPSERVER) &&\
		tar -cvf $(MAKEFILE_DIR)/$@ ./*




################# image #################
# TODO make iso: mkisofs -l -J -r -V fireCore -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o TC-remastered.iso newiso
# TODO filename
iso:
	# cd /tmp
	# mv tinycore.gz boot
	# mkdir newiso
	# mv boot newiso
	genisoimage \
		-l								`# allow full 31-character filenames` \
		-J 								`# add Joliet directory records` \
		-r  							`# add SUSP and RR records (Rock Ridge protocol)` \
		-V "fireCore" 					`# volume ID` \
		-no-emul-boot					`# no disk emulation (needed for non-floppy-disk media)` \
		-boot-load-size 4				`# number of "virtual" (512-byte) sectors to load in no-emulation mode` \
		-boot-info-table				`# add boot info table, containing info about iso fs for boot loaders` \
		-b boot/isolinux/isolinux.bin	`# el torito boot image` \
		-c boot/isolinux/boot.cat		`# el torito boot catalog` \
		-o TC-remastered.iso newiso



	genisoimage -l -J -r -V "fireCore" -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o fireCore.iso

















################# clean #################
# TODO split mount points, delete mount flags?
umount:
	echo "find mountpoints, unmount child dirs (longer paths) first"
	for mnt in $(shell mount | grep -oP '(?<= on )$(MAKEFILE_DIR)$(BUILD_DIR)\S*' | awk '{ print length, $$0 }' | sort -n -s -r | cut -d' ' -f2-); do \
		echo "umount $$mnt..."; \
		sudo umount -l "$$mnt"; \
	done

clean: umount
	sudo rm -rf $(BUILD_DIR) $(BOOT_DIR)







# TODO clean up phony targets
.PHONY: all clean umount debug deploy overlay remastered check tftpserver iso

# suppress the make deleting "intermediate files"
.PRECIOUS: $(PICORE_IMG1_DIR)/%.gz $(BUILD_DIR)/%.gz $(BUILD_DIR)/%.cpio






# depends on $(TFTP_FILES)
deploy: tftpserver
	# scp -r $(TFTPSERVER)/* root@OpenWrt.lan:/mnt/sda1
	rsync --archive --update $(TFTPSERVER)/ root@OpenWrt.lan:/mnt/sda1








# TODO two approaches

# A) single .img file, contains everything
# B) Needed TFTP files
# bootcode.bin