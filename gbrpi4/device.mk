# Per-board fragment for the gbrpi4 board. Lives at the board level, not the
# variant level — anything every gbrpi4 build needs (regardless of whether
# it's car/tv/base) belongs here, not in gbrpi4_car.mk.
#
# Currently empty: there's only one variant (gbrpi4_car) so the split is
# theoretical. Keep the file as the documented split point.
#
# TODO: when a second gbrpi4 variant is added (e.g. gbrpi4_tv), move the
# board-shared but variant-agnostic bits out of gbrpi4_car.mk and into here.
# The new variant's product makefile then
# $(call inherit-product, device/gborges/gbrpi4/device.mk) alongside its own
# variant-specific bits.
