# Included by per-board BoardConfig.mk AFTER the upstream brcm BoardConfig.mk,
# so these append (+=) to the upstream-set values rather than replacing them.

BOARD_SEPOLICY_DIRS              += device/gborges/common/sepolicy
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/gborges/common/sepolicy/system_ext
DEVICE_PACKAGE_OVERLAYS          += device/gborges/common/overlay
