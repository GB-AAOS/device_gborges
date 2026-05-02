# Variant of device/brcm/rpi4/mkbootimg.mk: copies upstream's boot/* and
# overlays/*, then appends gborges-specific config.txt deltas (SPI on,
# MCP2515 dtoverlay) before assembling the FAT boot image. Selected via
# BOARD_CUSTOM_BOOTIMG_MK in device/gborges/gbrpi4/BoardConfig.mk.

DEVICE_PATH  := device/brcm/rpi4
KERNEL_PATH  := device/brcm/rpi4-kernel
VENDOR_PATH  := vendor/brcm
GBORGES_PATH := device/gborges/gbrpi4

RPI_BOOT_OUT := $(PRODUCT_OUT)/rpiboot
$(RPI_BOOT_OUT): $(INSTALLED_RAMDISK_TARGET)
	mkdir -p $(RPI_BOOT_OUT)
	mkdir -p $(RPI_BOOT_OUT)/overlays
	cp $(DEVICE_PATH)/boot/* $(RPI_BOOT_OUT)
	cat $(GBORGES_PATH)/boot/config.txt.gborges >> $(RPI_BOOT_OUT)/config.txt
	cp $(KERNEL_PATH)/Image $(RPI_BOOT_OUT)
	cp $(KERNEL_PATH)/bcm2711-rpi-*.dtb $(RPI_BOOT_OUT)
	cp $(KERNEL_PATH)/overlays/* $(RPI_BOOT_OUT)/overlays
	cp $(PRODUCT_OUT)/ramdisk.img $(RPI_BOOT_OUT)
	cp $(VENDOR_PATH)/rpi4/proprietary/boot/* $(RPI_BOOT_OUT)
	echo $(BOARD_KERNEL_CMDLINE) > $(RPI_BOOT_OUT)/cmdline.txt

$(INSTALLED_BOOTIMAGE_TARGET): $(RPI_BOOT_OUT)
	$(call pretty,"Target boot image: $@")
	dd if=/dev/zero of=$@ bs=1M count=128
	mkfs.fat -F 32 -n "boot" $@
	mcopy -s -i $@ $(RPI_BOOT_OUT)/* ::
