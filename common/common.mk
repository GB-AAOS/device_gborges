# Shared product fragment for the gborges Pi family.
# Inherited by per-board product makefiles. Only put accumulating vars
# (PRODUCT_PACKAGES, PRODUCT_COPY_FILES, etc.) here — single-valued PRODUCT_*
# vars like PRODUCT_BRAND must be set in the leaf product makefile to override
# upstream reliably.

# PRODUCT_PACKAGES += \
#     libgpiod \
#     libgpiod_tools

# Enable ADB by default
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.usb.config=adb \
    ro.adb.secure=0 \
    ro.debuggable=1

# MDNS For wireless debugging
PRODUCT_PACKAGES += mdnsd

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    service.adb.tcp.port=5555 \
    persist.adb.tls_server.enable=1

# Raspberry Pi utils
PRODUCT_PACKAGES += \
    pinctrl

# gborges custom Vehicle HAL
PRODUCT_PACKAGES += \
    android.hardware.automotive.vehicle@V4-gborges-service

# NanoMQ MQTT broker
PRODUCT_PACKAGES += \
    nanomq \
    nanomq.conf \
    nanomq-mdns-advertise-gborges

# CAN bus: auto-load the SocketCAN + MCP2515 modules at boot. The .ko files
# are installed via BOARD_VENDOR_KERNEL_MODULES but nothing loads them, so
# this init .rc insmods them at post-fs (before the CAN HAL configures can0).
# See device/gborges/README.md (CAN bus section).
PRODUCT_COPY_FILES += \
    device/gborges/common/can/gborges-can.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/gborges-can.rc

# Wi-Fi seed (one-shot; reads /system/etc/gborges/wifi.conf if present).
# See device/gborges/common/wifi-seed/README.md.
PRODUCT_PACKAGES += gborges-wifi-seed

# Optional baked-in wifi.conf — gitignored. If a sibling wifi.conf exists
# next to wifi.conf.example at build time, install it; otherwise the seed
# script no-ops at boot.
ifneq ($(wildcard device/gborges/common/wifi-seed/wifi.conf),)
PRODUCT_COPY_FILES += \
    device/gborges/common/wifi-seed/wifi.conf:$(TARGET_COPY_OUT_SYSTEM)/etc/gborges/wifi.conf
endif
