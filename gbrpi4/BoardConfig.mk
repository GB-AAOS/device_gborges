# Board config for the gbrpi4 board. AOSP discovers this via PRODUCT_DEVICE :=
# gbrpi4 → */gbrpi4/BoardConfig.mk. Order matters: common appends to
# upstream-set vars, so it must come after the brcm include.

include device/brcm/rpi4/BoardConfig.mk
include device/gborges/common/BoardConfigCommon.mk

# Override boot.img assembly to layer gborges deltas (SPI + MCP2515 dtoverlay)
# on top of the upstream config.txt, without modifying device/brcm/rpi4/.
BOARD_CUSTOM_BOOTIMG_MK := device/gborges/gbrpi4/mkbootimg.mk

# Install CAN stack to /vendor/lib/modules/ so the MCP2515 driver bound by
# the dtoverlay above auto-loads via DT modalias. Upstream brcm ships no
# kernel modules; we add the ones SocketCAN needs end-to-end. depmod runs
# at build time and produces modules.dep / modules.alias next to these.
BOARD_VENDOR_KERNEL_MODULES := \
    device/brcm/rpi4-kernel/modules/can.ko \
    device/brcm/rpi4-kernel/modules/can-dev.ko \
    device/brcm/rpi4-kernel/modules/can-raw.ko \
    device/brcm/rpi4-kernel/modules/can-bcm.ko \
    device/brcm/rpi4-kernel/modules/mcp251x.ko
