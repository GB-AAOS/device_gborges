# Board config for the gbrpi5 board. AOSP discovers this via PRODUCT_DEVICE :=
# gbrpi5 → */gbrpi5/BoardConfig.mk. Order matters: common appends to
# upstream-set vars, so it must come after the brcm include.

include device/brcm/rpi5/BoardConfig.mk
include device/gborges/common/BoardConfigCommon.mk

# Override boot.img assembly to layer gborges deltas (SPI + MCP2515 dtoverlay)
# on top of the upstream config.txt, without modifying device/brcm/rpi5/.
BOARD_CUSTOM_BOOTIMG_MK := device/gborges/gbrpi5/mkbootimg.mk

# Install CAN stack to /vendor/lib/modules/ so the MCP2515 driver bound by
# the dtoverlay above auto-loads via DT modalias. depmod runs at build
# time and produces modules.dep / modules.alias next to these.
BOARD_VENDOR_KERNEL_MODULES := \
    device/gborges/gbrpi5-kernel/modules/can.ko \
    device/gborges/gbrpi5-kernel/modules/can-dev.ko \
    device/gborges/gbrpi5-kernel/modules/can-raw.ko \
    device/gborges/gbrpi5-kernel/modules/can-bcm.ko \
    device/gborges/gbrpi5-kernel/modules/mcp251x.ko
