# device/gborges

Project-specific device family for AOSP 16 (`android-16.0.0_r4`) on Raspberry
Pi 4 and Pi 5. A "downstream-light" hybrid: upstream `device/brcm/` (Raspberry
Vanilla / KonstaKANG) stays pristine, and this directory layers project
deltas on top via `inherit-product`.

The upstream `device/brcm/{rpi4,rpi5,rpi5-kernel}` projects come from the
Raspberry Vanilla local manifest:
<https://github.com/raspberry-vanilla/android_local_manifest>. Drop that
manifest's XML into `.repo/local_manifests/` and `repo sync` to populate
them. `device/gborges/` sits on top without modifying them.

The gbrpi4 kernel is gborges-side: `device/gborges/gbrpi4-kernel/` holds
the prebuilt `Image`, dtbs, vendor modules, and firmware overlays consumed
by the gbrpi4 boot image and vendor partition. It is built from the kernel
manifest at <https://github.com/GB-AAOS/android_kernel_manifest>; any
kernel-side change (defconfig deltas, module list, dtb/overlay sources)
goes there, and the resulting artifacts are restaged into `gbrpi4-kernel/`.
gbrpi5 consumes `device/brcm/rpi5-kernel`.

## Layout

```
device/gborges/
├── common/             shared fragments (product, board, sepolicy, overlay)
│   ├── common.mk
│   ├── BoardConfigCommon.mk
│   ├── canbus_config.pb    CAN HAL textproto (single bus CAN0, 250 kbps)
│   ├── sepolicy/
│   └── overlay/
├── gbrpi4/                 PRODUCT_DEVICE = gbrpi4
│   ├── AndroidProducts.mk
│   ├── BoardConfig.mk
│   ├── device.mk           board-shared, variant-agnostic (empty placeholder)
│   ├── gbrpi4_car.mk       variant: car
│   ├── mkbootimg.mk        fork of brcm's; appends boot/config.txt.gborges
│   └── boot/config.txt.gborges
├── gbrpi4-kernel/          prebuilt kernel artifacts for gbrpi4
│   ├── Image                   consumed by gbrpi4/mkbootimg.mk (Image,
│   ├── bcm2711-rpi-*.dtb       dtbs, overlays go into the boot image)
│   ├── modules/                and BoardConfig.mk's BOARD_VENDOR_KERNEL_MODULES
│   └── overlays/               (modules go into /vendor/lib/modules/)
└── gbrpi5/                 mirrors gbrpi4
```

## Lunch targets

```
lunch gbrpi4_car-bp4a-userdebug
lunch gbrpi5_car-bp4a-userdebug
```

`PRODUCT_NAME` uses underscores, never dashes — lunch parses
`<product>-<release>-<variant>` on `-`.

## Build & package

After `source build/envsetup.sh` and `lunch <target>`:

```
make bootimage systemimage vendorimage -j$(nproc)   # the three partitions mkimg needs
./rpi4-mkimg.sh                                     # or ./rpi5-mkimg.sh
```

`mkimg.sh` reads `${ANDROID_PRODUCT_OUT}` (set by lunch) and assembles a
flashable `.img` from the three partition images above. Pick the script
that matches the board you lunched — they're not interchangeable.

## Inheritance

Each leaf product makefile (`gbrpi4_car.mk`) inherits, in order:

1. `device/brcm/rpi4/aosp_rpi4_car.mk` — full upstream car product
2. `device/gborges/common/common.mk` — gborges baseline (libgpiod, …)
3. `device/gborges/gbrpi4/device.mk` — board-shared deltas

The five identity vars (`PRODUCT_NAME`, `PRODUCT_DEVICE`, `PRODUCT_MODEL`,
`PRODUCT_BRAND`, `PRODUCT_MANUFACTURER`) are re-set in the leaf makefile —
`inherit-product` does not reliably override single-valued `PRODUCT_*` vars.
Accumulating vars (`PRODUCT_PACKAGES +=`, `PRODUCT_COPY_FILES +=`) inherit
fine and stay in `common.mk`.

`BoardConfig.mk` is discovered by AOSP from `PRODUCT_DEVICE`; it includes
`device/brcm/rpi{4,5}/BoardConfig.mk` and
`device/gborges/common/BoardConfigCommon.mk`.

## Board / variant split

`device.mk` and `gbrpi4_car.mk` look redundant today because there is only
one variant. The split anticipates a second variant:

- **board-level** (`gbrpi4/device.mk`) — anything every gbrpi4 build needs,
  regardless of variant.
- **variant-level** (`gbrpi4_car.mk`) — only what the car variant adds.

`device.mk` stays empty until a second variant exists. Don't pre-fill it.

## Adding a variant

For `gbrpi4_tv` on top of an existing board:

1. Add `gbrpi4_tv.mk` under `gbrpi4/`. Inherit
   `device/brcm/rpi4/aosp_rpi4_tv.mk` + `common/common.mk` +
   `gbrpi4/device.mk`. Set the five identity vars in the leaf.
2. Register it in `gbrpi4/AndroidProducts.mk` (`PRODUCT_MAKEFILES` and
   `COMMON_LUNCH_CHOICES`).
3. Move anything board-shared but variant-agnostic out of `gbrpi4_car.mk`
   into `gbrpi4/device.mk`.

For a new board, mirror `gbrpi4/`.

## CAN bus (Waveshare RS485 CAN HAT)

Both boards target the **Waveshare RS485 CAN HAT**: MCP2515 on SPI0 CE0,
INT GPIO 25, **12 MHz** crystal, 250 kbps default. The HAT seats on the
40-pin header — no manual wiring, no level-shifting (the HAT is 3.3 V SPI
end-to-end). 120 Ω termination is selectable via on-board jumper.

Pins consumed by the HAT:

- **CAN (MCP2515):** SPI0 — GPIO 8 (CE0), GPIO 9 (MISO), GPIO 10 (MOSI),
  GPIO 11 (SCK); INT on GPIO 25.
- **RS485 (SC16IS752, not currently enabled):** SPI0 — GPIO 7 (CE1);
  INT on GPIO 24.

The crystal value in the overlay must match the hardware (12 MHz on this
HAT). Peer nodes on different crystals (e.g. an 8 MHz MCP2515 on an
Arduino) interoperate fine — the crystal is private to each node and only
the configured bitrate has to match on the bus.

How it's wired in the build:

- **Boot:** each board's `BoardConfig.mk` overrides `BOARD_CUSTOM_BOOTIMG_MK`
  to `gbrpi*/mkbootimg.mk`, a fork of the upstream brcm one that
  additionally `cat`s `gbrpi*/boot/config.txt.gborges` onto the assembled
  `config.txt` before mcopy. The fragment carries `dtparam=spi=on` and the
  `dtoverlay=mcp2515-can0,oscillator=12000000,interrupt=25,…` line.
- **HAL:** each car product makefile ships `canhalconfigurator-aidl` plus a
  textproto at `/system/etc/canbus_config.pb` (copied from
  `common/canbus_config.pb`). Default config path is hard-coded in
  `hardware/interfaces/automotive/can/aidl/default/tools/configurator/canhalconfigurator.cpp`
  as `/etc/canbus_config.pb` (resolves to `/system/etc/`).

To change bitrate or add buses, edit `common/canbus_config.pb`. To
change INT pin, oscillator freq, or SPI max freq, edit
`gbrpi*/boot/config.txt.gborges`. To add a second MCP2515 (`mcp2515-can1.dtbo`
already in `gbrpi4-kernel/overlays/` for gbrpi4, `device/brcm/rpi5-kernel/overlays/`
for gbrpi5), append a second `dtoverlay=` line and a second `buses:` entry.

**Caveat:** `mkbootimg.mk` is a near-clone of upstream's. If KonstaKANG
changes their boot-assembly recipe, the gborges fork ships stale boot
artifacts until merged — watch for diffs to `device/brcm/rpi*/mkbootimg.mk`
on every sync.

## GPIO

`pinctrl` (upstream brcm's userspace GPIO tool) is replaced with
`libgpiod`, manually checked into `external/libgpiod` and pulled in by
`common/common.mk`, so every gborges build gets it. Upstream brcm
continues to ship `pinctrl`; that's not modified here.

## Status

This directory and `external/libgpiod` are not yet in any repo manifest —
they exist on this checkout only. The upstream `device/brcm/` projects
they depend on are pulled in via the Raspberry Vanilla local manifest
(<https://github.com/raspberry-vanilla/android_local_manifest>), which is
also not in `.repo/manifests/default.xml` and must be added under
`.repo/local_manifests/` before `repo sync`.
