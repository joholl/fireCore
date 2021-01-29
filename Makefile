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
PICORE_IMG1_FILES = $(addprefix $(PICORE_IMG1_DIR)/,bootcode.bin config.txt start.elf fixup.dat rootfs-piCore-12.0.gz modules-5.4.51-piCore-v7.gz bcm2710-rpi-3-b.dtb cmdline.txt kernel5451v7.img)

################# overlay #################
PACKAGES_LIST = $(OVERLAY_DIR)/tmp/builtin/onboot.lst
PACKAGES_LIST_SRC = src/builtin/onboot.lst
PACKAGES_DIR = $(OVERLAY_DIR)/tmp/builtin/optional
PACKAGES = $(addprefix $(PACKAGES_DIR)/,$(shell cat $(PACKAGES_LIST_SRC)))

PYTHON_PACKAGES_LIST = $(BUILD_DIR)/overlay/tmp/wheel/onboot.lst
PYTHON_PACKAGES_LIST_SRC = src/wheel/onboot.lst
PYTHON_PACKAGES_DIR = $(BUILD_DIR)/overlay/tmp/wheel/optional
PYTHON_PACKAGES = $(addprefix $(PYTHON_PACKAGES_DIR)/,$(shell cat $(PYTHON_PACKAGES_LIST_SRC)))

OVERLAY_BOOTSCRIPT = $(OVERLAY_DIR)/opt/boot.sh
OVERLAY_BOOTSCRIPT_SRC = src/boot.sh

PICORE_ROOTFS_CPIO_DIR = $(BUILD_DIR)/rootfs-$(PICORE)_cpio
PICORE_ROOTFS_CPIO_FILES = $(PICORE_ROOTFS_CPIO_DIR)/opt/bootlocal.sh
OVERLAY_BOOTLOCAL = $(OVERLAY_DIR)/opt/bootlocal.sh

OVERLAY_APP = $(OVERLAY_DIR)/tmp/app/server.py
OVERLAY_APP_SRC = src/app/server.py

OVERLAY_FILES = $(PACKAGES_LIST) $(PACKAGES) $(PYTHON_PACKAGES_LIST) $(PYTHON_PACKAGES) $(OVERLAY_BOOTSCRIPT) $(OVERLAY_BOOTLOCAL) $(OVERLAY_APP)

OVERLAY_CPIO = $(BUILD_DIR)/overlay.cpio

OVERLAY_GZ = $(BUILD_DIR)/overlay.gz

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
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/releases/RPi/$(PICORE).zip

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

$(BUILD_DIR)/%.cpio: $(PICORE_IMG1_DIR)/%.gz
	gzip --decompress --keep --to-stdout $? > $@

$(BUILD_DIR)/%_cpio/$(DIRSTAMP): $(BUILD_DIR)/%.cpio
	cpio --extract --make-directories --file $? --directory $(dir $@) 2>/dev/null || true
	touch $@

$(PICORE_ROOTFS_CPIO_FILES): $(PICORE_ROOTFS_CPIO_DIR)/$(DIRSTAMP)
	touch $@


################# overlay #################
# $(BUILD_DIR)/%.pkg.tar.xz:
	# mkdir -p $(dir $@)
	# wget --output-document=$@ http://mirror.archlinuxarm.org/aarch64/community/$(basename $(basename $@)).pkg.tar.xz

# TODO http://ftp.debian.org/debian/pool/main/p/python3-defaults/python3_3.7.3-1_armhf.deb/$(basename $(basename $(notdir $@))).pkg.tar.xz

# # arch linux arm (community channel, use different url for e.g. extra)
# # TODO own target for $(BUILD_DIR)/%.pkg.tar.xz
# $(PACKAGES_DIR)/%.alarm.tcz: #$(BUILD_DIR)/%.pkg.tar.xz
# 	wget --output-document=$(BUILD_DIR)/$(basename $(basename $(notdir $@))) http://mirror.archlinuxarm.org/aarch64/community/$(basename $(basename $(notdir $@))).pkg.tar.xz
# 	mkdir -p $(basename $(basename $(notdir $@)))_untar
# 	tar -xf $(BUILD_DIR)/$(basename $(basename $(notdir $@))) -C $(basename $(basename $(notdir $@)))_untar
# 	mksquashfs $(basename $(basename $(notdir $@)))_untar $@

# # TODO these versions (here 13.x) need to be drilled down in settings (probably also arch (here armv6))
# %.unstable.tcz:
# 	echo $(PACKAGES_DIR)
# 	mkdir -p $(dir $@)
# 	wget --output-document=$@ http://tinycorelinux.net/13.x/armv6/tcz/$(basename $(basename $(notdir $@))).tcz

$(PACKAGES_LIST): $(PACKAGES_LIST_SRC)
	mkdir -p $(dir $@)
	cp $? $@

# PACKAGES:
%.tcz:
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/tcz/$(notdir $@)

$(PYTHON_PACKAGES_LIST): $(PYTHON_PACKAGES_LIST_SRC)
	mkdir -p $(dir $@)
	cp $? $@

# PYTHON_PACKAGES:
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
$(OVERLAY_BOOTLOCAL): $(PICORE_ROOTFS_CPIO_FILES)
	mkdir -p $(dir $@)
	cp $< $@
	echo "/opt/boot.sh" >> $@
	chmod 755 $@

# app
$(OVERLAY_APP): $(OVERLAY_APP_SRC)
	mkdir -p $(dir $@)
	cp $< $@
	chmod 755 $@

# requires all of the above
$(OVERLAY_CPIO): $(OVERLAY_FILES)
	cd $(OVERLAY_DIR); find . | cpio --create --owner='1001:50' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff

$(OVERLAY_GZ): $(OVERLAY_CPIO)
	gzip --recursive $? --to-stdout > $@

overlay: $(OVERLAY_GZ)


################# remastered (boot folder) #################
$(PICORE_REMASTERED_FILES): $(PICORE_IMG1_FILES) $(OVERLAY_GZ)
	mkdir -p $(dir $@)
	cp -r --preserve=mode,ownership $(PICORE_IMG1_DIR)/* $(dir $@)
	cp $(OVERLAY_GZ) $(dir $@)
	sed -i "s/\(initramfs [^ ]*\)/\1,$(notdir $(OVERLAY_GZ))/g" $(dir $@)/config.txt

remastered: $(PICORE_REMASTERED_FILES)


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