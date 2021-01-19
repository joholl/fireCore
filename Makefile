# Settings
PICORE_VERSION_MAJOR = 12
PICORE_VERSION_MINOR =  0

# General Directories
DOWNLOAD_DIR = download
BUILD_DIR = build
DEBUG_DIR = debug
BOOT_DIR = boot

# Target paths
PICORE = piCore-$(PICORE_VERSION_MAJOR).$(PICORE_VERSION_MINOR)
PICORE_ZIP = $(DOWNLOAD_DIR)/$(PICORE).zip
PICORE_UNZIP_DIR = $(BUILD_DIR)/$(PICORE)_unzip
# MS/DOS partition table + boot partition + tce partition
PICORE_IMG = $(PICORE_UNZIP_DIR)/$(PICORE).img
# boot partition
PICORE_IMG1= $(BUILD_DIR)/$(PICORE).img1
# boot partition (extracted)
PICORE_IMG1_DIR = $(BUILD_DIR)/$(PICORE)_img1
PICORE_ROOTFS_DIR = $(BUILD_DIR)/rootfs-$(PICORE)_cpio
PICORE_OVERLAY_DIR = $(BUILD_DIR)/overlay
PICORE_OVERLAY_BUILTIN_DIR = $(PICORE_OVERLAY_DIR)/tmp/builtin
PICORE_OVERLAY_OPTIONAL_DIR = $(PICORE_OVERLAY_BUILTIN_DIR)/optional
PICORE_OVERLAY_CPIO = $(PICORE_OVERLAY_DIR).cpio
PICORE_REMASTERED_DIR = $(BOOT_DIR)



all: remastered

remastered: $(PICORE_REMASTERED_DIR)

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
	# TODO what about owner and permissions?
	mcopy -p -i $? ::* $@

%.gz: $(PICORE_IMG1_DIR)

%.cpio: %.gz
	gzip --decompress --keep --to-stdout $(PICORE_IMG1_DIR)/$(notdir $?) > $@

%_cpio: %.cpio
	cpio --extract --file $? --make-directories --preserve-modification-time --directory --warning=none $@ || true

%.tcz:
	mkdir -p $(dir $@)
	wget --output-document=$@ http://tinycorelinux.net/$(PICORE_VERSION_MAJOR).x/armv6/tcz/$(notdir $?)

# TODO dont target dir, bc it would exist after make <...>.tcz
# instead, target onboot.lst
$(PICORE_OVERLAY_DIR): $(PICORE_OVERLAY_OPTIONAL_DIR)/openssh.tcz $(PICORE_OVERLAY_OPTIONAL_DIR)/openssl.tcz
	mkdir -p $(PICORE_OVERLAY_OPTIONAL_DIR)
	rm -f $(PICORE_OVERLAY_BUILTIN_DIR)/onboot.lst
	$(foreach dep,$(notdir $?),echo "${dep}" >> $(PICORE_OVERLAY_BUILTIN_DIR)/onboot.lst;)

$(PICORE_REMASTERED_DIR): $(PICORE_IMG1_DIR) $(PICORE_OVERLAY_DIR)
	mkdir -p $@
	# TODO sudo sh -c "echo 'tc:piCore' | chpasswd"

$(PICORE_OVERLAY_CPIO):
	echo ez

clean:
	rm -rf $(DOWNLOAD_DIR) $(BUILD_DIR) $(DEBUG_DIR) $(BOOT_DIR)

.PHONY: all clean $(PICORE_OVERLAY_DIR)