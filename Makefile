# settings
PICORE_VERSION_MAJOR = 12
PICORE_VERSION_MINOR =  0

PICORE = piCore-$(PICORE_VERSION_MAJOR).$(PICORE_VERSION_MINOR)

BOOTSCRIPT = src/boot.sh

# general directories
DOWNLOAD_DIR = download
BUILD_DIR = build
FS_DIR = fs
BOOT_DIR = boot

# non-targets
PICORE_OVERLAY_DIR = $(BUILD_DIR)/overlay
PICORE_OVERLAY_BUILTIN_DIR = $(PICORE_OVERLAY_DIR)/tmp/builtin
PICORE_OVERLAY_OPTIONAL_DIR = $(PICORE_OVERLAY_BUILTIN_DIR)/optional

# target paths
PICORE_ZIP = $(DOWNLOAD_DIR)/$(PICORE).zip
PICORE_UNZIP_DIR = $(BUILD_DIR)/$(PICORE)_unzip
# MS/DOS partition table + boot partition + tce partition
PICORE_IMG = $(PICORE_UNZIP_DIR)/$(PICORE).img
# boot partition
PICORE_IMG1 = $(BUILD_DIR)/$(PICORE).img1
# boot partition (extracted)
PICORE_IMG1_DIR = $(BUILD_DIR)/$(PICORE)_img1
# onboot.lst including packages and boot scripts
PICORE_OVERLAY = $(PICORE_OVERLAY_BUILTIN_DIR)/onboot.lst
PICORE_OVERLAY_BOOTSCRIPT = $(PICORE_OVERLAY_DIR)/opt/$(notdir $(BOOTSCRIPT))
PICORE_OVERLAY_BOOTLOCAL = $(PICORE_OVERLAY_DIR)/opt/bootlocal.sh
# overlay archives
PICORE_OVERLAY_CPIO = $(BUILD_DIR)/overlay.cpio
PICORE_OVERLAY_GZ = $(BUILD_DIR)/overlay.gz
# remastered tinyCore aka fireCore
PICORE_REMASTERED_DIR = $(BOOT_DIR)
# re-extract file system archives for debugging
PICORE_ROOTFS_CPIO_DIR = $(BUILD_DIR)/rootfs-$(PICORE)_cpio
PICORE_MODULES_CPIO_DIR = $(BUILD_DIR)/modules-5.4.51-piCore-v7_cpio
PICORE_OVERLAY_CPIO_DIR = $(BUILD_DIR)/overlay_cpio

# TODO dirstamps? does not work for unzipping into dirstampt dir... multiple targets?

all: remastered

################# boot partition #################
$(PICORE_ZIP):
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/releases/RPi/$(PICORE).zip

$(PICORE_UNZIP_DIR): $(PICORE_ZIP)
	mkdir -p $(dir $@)
	unzip -d $@ $?

$(PICORE_IMG): $(PICORE_UNZIP_DIR)

$(PICORE_IMG1): $(PICORE_IMG)
	dd if=$? of=$@ skip=$(shell sfdisk --json $? | jq ".partitiontable.partitions[0].start") count=$(shell sfdisk --json $? | jq ".partitiontable.partitions[0].size")

$(PICORE_IMG1_DIR): $(PICORE_IMG1)
	mkdir -p $@
	# boot partition file owner does not matter as long as it is world-readable
	mcopy -p -s -i $? ::* $@
	sudo chmod 755 $@/*

################# overlay #################
%.tcz:
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/tcz/$(notdir $@)

$(PICORE_OVERLAY_BOOTSCRIPT):
	mkdir -p $(dir $@)
	cp $(BOOTSCRIPT) $@
	chmod 755 $@

$(PICORE_OVERLAY_BOOTLOCAL): $(PICORE_ROOTFS_CPIO_DIR) $(PICORE_OVERLAY_BOOTSCRIPT)
	cp $</opt/bootlocal.sh $@
	echo "/opt/boot.sh" >> $@
	chmod 755 $@

$(PICORE_OVERLAY): $(PICORE_OVERLAY_OPTIONAL_DIR)/openssh.tcz $(PICORE_OVERLAY_OPTIONAL_DIR)/openssl.tcz $(PICORE_OVERLAY_BOOTLOCAL)
	$(foreach dep,$(notdir $?),echo "${dep}" >> $@;)
	# TODO sudo sh -c "echo 'tc:piCore' | chpasswd"

$(PICORE_OVERLAY_CPIO): $(PICORE_OVERLAY)
	cd $(PICORE_OVERLAY_DIR); find . | cpio --create --owner='1001:50' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff

$(PICORE_OVERLAY_GZ): $(PICORE_OVERLAY_CPIO)
	gzip --recursive $? --to-stdout > $@

overlay: $(PICORE_OVERLAY_GZ)

################# remastered (boot folder) #################
$(PICORE_REMASTERED_DIR): $(PICORE_IMG1_DIR) $(PICORE_OVERLAY_GZ)
	mkdir $@
	cp -rp $(PICORE_IMG1_DIR)/* $@
	cp $(PICORE_OVERLAY_GZ) $@
	sed -i "s/\(initramfs [^ ]*\)/\1,$(notdir $(PICORE_OVERLAY_GZ))/g" $@/config.txt

remastered: $(PICORE_REMASTERED_DIR)

################# file systems (except overlay) #################
$(PICORE_IMG1_DIR)/%.gz: $(PICORE_IMG1_DIR)
	# TODO pattern does not match if rule is empty?
	echo ""

$(BUILD_DIR)/%.gz: $(PICORE_IMG1_DIR)/%.gz
	cp $? $@

$(BUILD_DIR)/%.cpio: $(BUILD_DIR)/%.gz
	gzip --decompress --keep --to-stdout $? > $(BUILD_DIR)/$(notdir $@)

$(BUILD_DIR)/%_cpio: $(BUILD_DIR)/%.cpio
	cpio --extract --make-directories --preserve-modification-time --warning=none --file $? --directory $@ || true

debug: $(PICORE_ROOTFS_CPIO_DIR) $(PICORE_MODULES_CPIO_DIR) $(PICORE_OVERLAY_CPIO_DIR)
	mkdir -p $@

# TODO make clean; make fs -> not rule to make target 'fs/rootfs-piCore-12.0_cpio'

################# fs #################
deploy: $(PICORE_REMASTERED_DIR)
	# TODO TFTP_DIR variable
	rm -rf /tftpboot/*
	cp -rp $?/* /tftpboot

################# clean #################
clean:
	rm -rf $(DOWNLOAD_DIR) $(BUILD_DIR) $(FS_DIR) $(BOOT_DIR)


.PHONY: all remastered deploy debug clean

# suppress the make deleting "intermediate files"
.PRECIOUS: $(PICORE_IMG1_DIR)/%.gz $(BUILD_DIR)/%.gz $(BUILD_DIR)/%.cpio