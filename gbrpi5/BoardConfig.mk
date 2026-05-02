# Board config for the gbrpi5 board. AOSP discovers this via PRODUCT_DEVICE :=
# gbrpi5 → */gbrpi5/BoardConfig.mk. Order matters: common appends to
# upstream-set vars, so it must come after the brcm include.

include device/brcm/rpi5/BoardConfig.mk
include device/gborges/common/BoardConfigCommon.mk

# Override boot.img assembly to layer gborges deltas (SPI + MCP2515 dtoverlay)
# on top of the upstream config.txt, without modifying device/brcm/rpi5/.
BOARD_CUSTOM_BOOTIMG_MK := device/gborges/gbrpi5/mkbootimg.mk
