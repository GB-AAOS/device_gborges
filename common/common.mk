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
