# Board config for the gbrpi4 board. AOSP discovers this via PRODUCT_DEVICE :=
# gbrpi4 → */gbrpi4/BoardConfig.mk. Order matters: common appends to
# upstream-set vars, so it must come after the brcm include.

include device/brcm/rpi4/BoardConfig.mk
include device/gborges/common/BoardConfigCommon.mk

# Override boot.img assembly to layer gborges deltas (SPI + MCP2515 dtoverlay)
# on top of the upstream config.txt, without modifying device/brcm/rpi4/.
BOARD_CUSTOM_BOOTIMG_MK := device/gborges/gbrpi4/mkbootimg.mk
