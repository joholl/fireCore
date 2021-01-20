# settings
PICORE_VERSION_MAJOR = 12
PICORE_VERSION_MINOR =  0

PICORE = piCore-$(PICORE_VERSION_MAJOR).$(PICORE_VERSION_MINOR)

# general directories
DOWNLOAD_DIR = download
BUILD_DIR = build
DEBUG_DIR = debug
BOOT_DIR = boot

# target paths
PICORE_ZIP = $(DOWNLOAD_DIR)/$(PICORE).zip
PICORE_UNZIP_DIR = $(BUILD_DIR)/$(PICORE)_unzip
# MS/DOS partition table + boot partition + tce partition
PICORE_IMG = $(PICORE_UNZIP_DIR)/$(PICORE).img
# boot partition
PICORE_IMG1 = $(BUILD_DIR)/$(PICORE).img1
# boot partition (extracted)
PICORE_IMG1_DIR = $(BUILD_DIR)/$(PICORE)_img1
# onboot.lst including packages
PICORE_OVERLAY = $(PICORE_OVERLAY_BUILTIN_DIR)/onboot.lst
PICORE_OVERLAY_CPIO = $(BUILD_DIR)/overlay.cpio
PICORE_OVERLAY_GZ = $(BUILD_DIR)/overlay.gz
PICORE_REMASTERED_DIR = $(BOOT_DIR)
# non-targets
PICORE_OVERLAY_DIR = $(BUILD_DIR)/overlay
PICORE_OVERLAY_BUILTIN_DIR = $(PICORE_OVERLAY_DIR)/tmp/builtin
PICORE_OVERLAY_OPTIONAL_DIR = $(PICORE_OVERLAY_BUILTIN_DIR)/optional

# debug
DEBUG_PICORE_ROOTFS_DIR = $(DEBUG_DIR)/rootfs-$(PICORE)_cpio
DEBUG_PICORE_MODULES_DIR = $(DEBUG_DIR)/modules-5.4.51-piCore-v7_cpio
DEBUG_PICORE_OVERLAY_DIR = $(DEBUG_DIR)/overlay_cpio



all: remastered


################# boot partition #################
$(PICORE_ZIP):
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/releases/RPi/$(PICORE).zip

$(PICORE_UNZIP_DIR): $(PICORE_ZIP)
	mkdir -p $@
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

$(PICORE_OVERLAY): $(PICORE_OVERLAY_OPTIONAL_DIR)/openssh.tcz $(PICORE_OVERLAY_OPTIONAL_DIR)/openssl.tcz
	$(foreach dep,$(notdir $?),echo "${dep}" >> $@;)
	# TODO sudo sh -c "echo 'tc:piCore' | chpasswd"

$(PICORE_OVERLAY_CPIO): $(PICORE_OVERLAY)
	cd $(PICORE_OVERLAY_DIR); find . | cpio --create --owner='1001:50' --format newc --file $(realpath .)/$@  # 1001:50 is tc:staff

$(PICORE_OVERLAY_GZ): $(PICORE_OVERLAY_CPIO)
	gzip --recursive $? --to-stdout > $@

overlay: $(PICORE_OVERLAY_GZ)

################# remastered (boot folder) #################
$(PICORE_REMASTERED_DIR): $(PICORE_IMG1_DIR) $(PICORE_OVERLAY_GZ)
	mkdir -p $@
	cp -rp $(PICORE_IMG1_DIR)/* $@
	cp $(PICORE_OVERLAY_GZ) $@
	sed -i "s/\(initramfs [^ ]*\)/\1,$(notdir $(PICORE_OVERLAY_GZ))/g" $@/config.txt

remastered: $(PICORE_REMASTERED_DIR)

################# debug #################
$(PICORE_REMASTERED_DIR)/%.gz: $(PICORE_REMASTERED_DIR)

$(BUILD_DIR)/%.cpio: $(PICORE_REMASTERED_DIR)/%.gz
	gzip --decompress --keep --to-stdout $? > $(BUILD_DIR)/$(notdir $@)

$(DEBUG_DIR)/%_cpio: $(BUILD_DIR)/%.cpio
	cpio --extract --make-directories --preserve-modification-time --warning=none --file $? --directory $@ || true

$(DEBUG_DIR): $(DEBUG_PICORE_ROOTFS_DIR) $(DEBUG_PICORE_MODULES_DIR) $(DEBUG_PICORE_OVERLAY_DIR)

# TODO make clean; make debug -> not rule to make target 'debug/rootfs-piCore-12.0_cpio'

################# debug #################
deploy: $(PICORE_REMASTERED_DIR)
	# TODO TFTP_DIR variable
	rm -rf /tftpboot/*
	cp -rp $?/* /tftpboot

################# clean #################
clean:
	rm -rf $(DOWNLOAD_DIR) $(BUILD_DIR) $(DEBUG_DIR) $(BOOT_DIR)


.PHONY: all deploy clean

# suppress the make deleting "intermediate files"
.PRECIOUS: %.gz