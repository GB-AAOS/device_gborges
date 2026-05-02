# Per-board fragment for the gbrpi5 board. Lives at the board level, not the
# variant level — anything every gbrpi5 build needs (regardless of whether
# it's car/tv/base) belongs here, not in gbrpi5_car.mk.
#
# Currently empty: there's only one variant (gbrpi5_car) so the split is
# theoretical. Keep the file as the documented split point.
#
# TODO: when a second gbrpi5 variant is added (e.g. gbrpi5_tv), move the
# board-shared but variant-agnostic bits out of gbrpi5_car.mk and into here.
# The new variant's product makefile then
# $(call inherit-product, device/gborges/gbrpi5/device.mk) alongside its own
# variant-specific bits.
