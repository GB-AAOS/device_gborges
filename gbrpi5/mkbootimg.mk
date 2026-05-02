# Variant of device/brcm/rpi5/mkbootimg.mk: copies upstream's boot/* and
# overlays/*, then appends gborges-specific config.txt deltas (SPI on,
# MCP2515 dtoverlay) before assembling the FAT boot image. Selected via
# BOARD_CUSTOM_BOOTIMG_MK in device/gborges/gbrpi5/BoardConfig.mk.

DEVICE_PATH  := device/brcm/rpi5
KERNEL_PATH  := device/brcm/rpi5-kernel
GBORGES_PATH := device/gborges/gbrpi5

RPI_BOOT_OUT := $(PRODUCT_OUT)/rpiboot
$(RPI_BOOT_OUT): $(INSTALLED_RAMDISK_TARGET)
	mkdir -p $(RPI_BOOT_OUT)
	mkdir -p $(RPI_BOOT_OUT)/overlays
	cp $(DEVICE_PATH)/boot/* $(RPI_BOOT_OUT)
	cat $(GBORGES_PATH)/boot/config.txt.gborges >> $(RPI_BOOT_OUT)/config.txt
	cp $(KERNEL_PATH)/Image $(RPI_BOOT_OUT)
	cp $(KERNEL_PATH)/bcm2712*-rpi-*.dtb $(RPI_BOOT_OUT)
	cp $(KERNEL_PATH)/overlays/* $(RPI_BOOT_OUT)/overlays
	cp $(PRODUCT_OUT)/ramdisk.img $(RPI_BOOT_OUT)
	echo $(BOARD_KERNEL_CMDLINE) > $(RPI_BOOT_OUT)/cmdline.txt

$(INSTALLED_BOOTIMAGE_TARGET): $(RPI_BOOT_OUT)
	$(call pretty,"Target boot image: $@")
	dd if=/dev/zero of=$@ bs=1M count=128
	mkfs.fat -F 32 -n "boot" $@
	mcopy -s -i $@ $(RPI_BOOT_OUT)/* ::
