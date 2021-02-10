# settings
PICORE_VERSION_MAJOR = 12
PICORE_VERSION_MINOR =  0

PICORE = piCore-$(PICORE_VERSION_MAJOR).$(PICORE_VERSION_MINOR)

# general directories
BUILD_DIR = build
OVERLAY_DIR = $(BUILD_DIR)/overlay
BOOT_DIR = boot

DIRSTAMP = .dirstamp

################# boot partition #################
PICORE_ZIP = $(BUILD_DIR)/$(PICORE).zip
PICORE_UNZIP_DIR = $(BUILD_DIR)/$(PICORE)_unzip
PICORE_UNZIP_FILES = $(PICORE_UNZIP_DIR)/$(PICORE).img
# MS/DOS partition table + boot partition + tce partition
PICORE_IMG = $(PICORE_UNZIP_DIR)/$(PICORE).img
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
PACKAGES = $(addprefix $(PACKAGES_DIR)/,$(shell cat $(PACKAGES_LIST_SRC)))

PYTHON_PACKAGES_LIST_SRC = src/python-packages.lst

OVERLAY_BOOTSCRIPT = $(OVERLAY_DIR)/opt/boot.sh
OVERLAY_BOOTSCRIPT_SRC = src/boot.sh

OVERLAY_BOOTLOCAL = $(OVERLAY_DIR)/opt/bootlocal.sh

OVERLAY_APP = $(OVERLAY_DIR)/tmp/app/server.py
OVERLAY_APP_SRC = src/app/server.py

OVERLAY_FILES = $(OVERLAY_BOOTSCRIPT) $(OVERLAY_BOOTLOCAL) $(OVERLAY_APP)

OVERLAY_CPIO = $(BUILD_DIR)/overlay.cpio

OVERLAY_GZ = $(BUILD_DIR)/overlay.gz

# TODO remove touch and dirstamp leftover code?

# TODO add variable for arch, switch armv7l instead of armv7?

################# remastered #################
PICORE_REMASTERED_DIR = $(BOOT_DIR)
PICORE_REMASTERED_FILES = $(addprefix $(PICORE_REMASTERED_DIR)/,$(notdir $(PICORE_IMG1_FILES) $(OVERLAY_GZ)))

################# debug #################
MODULES_CPIO_DIR = $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio
OVERLAY_CPIO_DIR = $(BUILD_DIR)/overlay_cpio

################# deploy #################
TFTP_DIR = /tftpboot
TFTP_FILES = $(addprefix $(TFTP_DIR)/,$(notdir $(PICORE_REMASTERED_FILES)))


# remastered tinyCore aka fireCore
# re-extract file system archives for debugging
PICORE_MODULES_CPIO_DIR = $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio
OVERLAY_CPIO_DIR = $(BUILD_DIR)/overlay_cpio


all: remastered


################# boot partition #################
$(PICORE_ZIP):
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv7/releases/RPi/$(PICORE).zip

$(PICORE_UNZIP_FILES): $(PICORE_ZIP)
	mkdir -p $(dir $@)
	unzip -d $(dir $@) $?

$(PICORE_IMG1): $(PICORE_UNZIP_FILES)
	mkdir -p $(dir $@)
	dd if=$? of=$@ skip=$(shell sfdisk --json $? | jq ".partitiontable.partitions[0].start") count=$(shell sfdisk --json $? | jq ".partitiontable.partitions[0].size")

$(PICORE_IMG1_FILES): $(PICORE_IMG1)
	echo TARGETS:  $@
	mkdir -p $(dir $@)
	# boot partition file owner does not matter as long as it is world-readable
	mcopy -p -s -i $? ::* $(dir $@)
	sudo chmod 755 $(dir $@)/*

$(BUILD_DIR)/%.gz: $(PICORE_IMG1_DIR)/%.gz
	cp $? $@

$(BUILD_DIR)/%.cpio: $(BUILD_DIR)/%.gz
	gzip --decompress --keep --to-stdout $? > $@
	# TODO recompress to save space: advdef -z4 ...

$(BUILD_DIR)/%_cpio/$(DIRSTAMP): $(BUILD_DIR)/%.cpio
	mkdir -p $(dir $@)
	# TODO only sudo can make char devices, maybe chroot?
	cpio --extract --make-directories --file $? --directory $(dir $@) || true
	touch $@

$(ROOTFS_REMASTERED_CPIO_FILES): $(ROOTFS_REMASTERED_CPIO_DIR)/$(DIRSTAMP)
	touch $@

################# rootfs + rootfs remastered #################
# Install packages, generate ssh keys
# TODO use https://unix.stackexchange.com/questions/41889/how-can-i-chroot-into-a-filesystem-with-a-different-architechture
#   sudo cp $(which qemu-arm-static) build/rootfs-piCore-12.0_remastered_cpio/usr/bin/
#   sudo chroot build/rootfs-piCore-12.0_remastered_cpio/ qemu-arm-static /bin/sh
# TODO we need to install packages by unsquashing? solve the proc device thing?
$(ROOTFS_REMASTERED_CPIO_DIR)/$(DIRSTAMP): $(ROOTFS_CPIO_DIR)/$(DIRSTAMP) $(PACKAGES)
	mkdir -p $(dir $@)
	sudo cp -r --preserve=mode,ownership $(dir $<)/* $(dir $@)
	# extract packages into rootfs
	for pkg in $(PACKAGES); do \
		sudo unsquashfs -f -d $(dir $@) $$pkg; \
	done
	# set nameserver to enable pip downloads
	cp /etc/resolv.conf $(dir $@)/etc/resolv.conf
	# TODO use qemu instead to enable building on x86 archs
	chroot $(dir $@) /bin/sh -c " \
		export LD_LIBRARY_PATH=/usr/local/lib; \
		find /usr/local/tce.installed -type f -exec {} \;; \
		python3 -m pip install $(shell cat $(PYTHON_PACKAGES_LIST_SRC)); \
		/usr/local/etc/init.d/openssh start; \
	"
	touch $@

################# overlay #################
# PACKAGES (deprecated):
# http://tinycorelinux.net/12.x/armv7/tcz/
%.tcz:
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv7/tcz/$(notdir $@)

# PYTHON_PACKAGES (deprecated):
# e.g.
# wget -qO- https://pypi.org/pypi/<name>/json | jq '.info.version'
# wget -qO- https://pypi.org/pypi/<name>/json | jq '.releases."<version>"[] | select(.packagetype == "bdist_wheel")' | jq '.filename'
%.whl:
	mkdir -p $(dir $@)
	wget --output-document=$@ $(shell wget -qO- https://pypi.org/pypi/$(word 1,$(subst -, ,$(notdir $@)))/json | jq '.releases."$(word 2,$(subst -, ,$(notdir $@)))"[] | select(.packagetype == "bdist_wheel") | .url')

# boot.sh
$(OVERLAY_BOOTSCRIPT): $(OVERLAY_BOOTSCRIPT_SRC)
	mkdir -p $(dir $@)
	cp $? $@
	chmod 755 $@

# bootlocal.sh
$(OVERLAY_BOOTLOCAL): $(ROOTFS_REMASTERED_CPIO_FILES)
	mkdir -p $(dir $@)
	cp $< $@
	echo "/opt/boot.sh" >> $@
	chmod 755 $@

# app
$(OVERLAY_APP): $(OVERLAY_APP_SRC)
	mkdir -p $(dir $@)
	cp $< $@
	chmod 755 $@

# TODO also includes left-over files (e.g. packets)... pass OVERLAY_FILES with relative path?
# requires all of the above
$(OVERLAY_CPIO): $(OVERLAY_FILES)
	cd $(OVERLAY_DIR); find . | cpio --create --owner='1001:50' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff

$(OVERLAY_GZ): $(OVERLAY_CPIO)
	gzip --recursive $? --to-stdout > $@
	# TODO recompress to save space: advdef -z4 ...

overlay: $(OVERLAY_GZ)


################# remastered (boot folder) #################
$(PICORE_REMASTERED_FILES): $(PICORE_IMG1_FILES) $(OVERLAY_GZ)
	mkdir -p $(dir $@)
	cp -r --preserve=mode,ownership $(PICORE_IMG1_DIR)/* $(dir $@)
	cp $(OVERLAY_GZ) $(dir $@)
	# modify config.txt
	sed -i "s/\(initramfs [^ ]*\)/\1,$(notdir $(OVERLAY_GZ))/g" $(dir $@)/config.txt
	echo "$(shell cat src/config.txt.append)" >> $(dir $@)/config.txt

remastered: $(PICORE_REMASTERED_FILES)

# TODO make iso: mkisofs -l -J -r -V fireCore -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o TC-remastered.iso newiso
# TODO filename
iso:
	genisoimage -l -J -r -V fireCore -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o fireCore.iso newiso

################# debug #################
debug: $(MODULES_CPIO_DIR)/$(DIRSTAMP) $(OVERLAY_CPIO_DIR)/$(DIRSTAMP)

################# deploy #################
$(TFTP_FILES): $(PICORE_REMASTERED_FILES)
	rm -rf /tftpboot/*
	cp -r --preserve=mode,ownership $? /tftpboot

deploy: $(TFTP_FILES)


################# clean #################
clean:
	rm -rf $(BUILD_DIR) $(BOOT_DIR)


.PHONY: all clean debug deploy overlay remastered

# suppress the make deleting "intermediate files"
.PRECIOUS: $(PICORE_IMG1_DIR)/%.gz $(BUILD_DIR)/%.gz $(BUILD_DIR)/%.cpio
