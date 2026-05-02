$(call inherit-product, device/brcm/rpi4/aosp_rpi4_car.mk)
$(call inherit-product, device/gborges/common/common.mk)
$(call inherit-product, device/gborges/gbrpi4/device.mk)

# CAN HAL configurator + bus textproto. Brings up CAN0 (mcp2515 -> can0) at boot.
PRODUCT_PACKAGES += canhalconfigurator-aidl
PRODUCT_COPY_FILES += \
    device/gborges/common/canbus_config.pb:$(TARGET_COPY_OUT_SYSTEM)/etc/canbus_config.pb

# Identity overrides come AFTER the inherits. PRODUCT_BRAND / PRODUCT_MANUFACTURER
# must be set here (not in common.mk) — when the same single-valued PRODUCT_*
# var is set in two inherited fragments, AOSP doesn't reliably take the
# later-inherited value, so the override has to live in the leaf product makefile.
PRODUCT_NAME         := gbrpi4_car
PRODUCT_DEVICE       := gbrpi4
PRODUCT_MODEL        := gborges Pi 4 (Automotive)
PRODUCT_BRAND        := gborges
PRODUCT_MANUFACTURER := gborges
