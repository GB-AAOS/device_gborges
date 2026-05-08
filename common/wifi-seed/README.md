# gborges-wifi-seed

One-shot init service that adds one or more Wi-Fi networks to the
saved-networks list on first boot, so a freshly flashed device joins
known SSIDs without manual setup.

## How it works

1. Build a system image with a populated `wifi.conf` baked in (see below).
2. Flash. On first boot, `sys.boot_completed=1` fires and init starts the
   `gborges-wifi-seed` service.
3. The script reads `/system/etc/gborges/wifi.conf` and iterates over the
   numbered network entries (`SSID_1`, `SSID_2`, …). For each it runs
   `cmd wifi add-network`, then writes
   `/data/local/tmp/.gborges-wifi-seeded` so it doesn't re-run. Android's
   normal auto-join picks whichever saved network is in range.

If `wifi.conf` is absent on the device, the script exits silently — no
breakage, the device just boots with no preconfigured network.

`wifi.conf.example` lives only in the source tree as a developer-facing
template — it is not shipped to the device.

Wi-Fi is also forced on as part of the seed: after adding networks the
script runs `cmd wifi set-wifi-enabled enabled`. This is belt-and-suspenders
on top of the static overlay at
`device/gborges/common/overlay/frameworks/base/packages/SettingsProvider/res/values/defaults.xml`
(`def_wifi_on=true`) — the overlay only seeds `WIFI_ON` on first DB
create, so a system-only reflash that preserves `/data` would otherwise
keep an old persisted `WIFI_ON=0` and the seeded networks couldn't
auto-join. The script's flip is gated by the marker, so the user can
still turn Wi-Fi off later via Settings without the seed fighting them
on the next boot.

## Baking in credentials

```sh
cp device/gborges/common/wifi-seed/wifi.conf.example \
   device/gborges/common/wifi-seed/wifi.conf
$EDITOR device/gborges/common/wifi-seed/wifi.conf
```

`wifi.conf` is `.gitignore`d. Then rebuild and flash:

```sh
m systemimage
./rpi4-mkimg.sh && ./rpi4-wrimg.sh system     # or rpi5-*
```

The conditional `PRODUCT_COPY_FILES` rule in `device/gborges/common/common.mk`
installs `wifi.conf` only if the source file exists; absent it, only
`wifi.conf.example` ships.

## Config format

POSIX-shell `KEY=VALUE` pairs sourced by `/system/bin/gborges-wifi-seed`.
Networks are numbered starting at 1; the script stops at the first
missing `SSID_N` (no gaps). Per-network keys (`N` = 1, 2, 3, …):

| key          | required             | values                            |
| ------------ | -------------------- | --------------------------------- |
| `SSID_N`     | yes                  | quoted string                     |
| `PSK_N`      | yes for wpa2/wpa3    | quoted string                     |
| `SECURITY_N` | no                   | `open`, `wpa2` (default), `wpa3`  |
| `HIDDEN_N`   | no                   | `0` (default), `1`                |

Example with two networks:

```sh
SSID_1="HomeNet"
PSK_1="correct horse battery staple"
SECURITY_1=wpa2

SSID_2="OpenGuestAP"
SECURITY_2=open
```

## Reseeding

`/data/local/tmp/.gborges-wifi-seeded` blocks repeat runs. To force a
re-seed without flashing:

```sh
adb shell rm -f /data/local/tmp/.gborges-wifi-seeded
adb reboot
```

Factory-reset wipes `/data`, so a wiped device re-seeds automatically on
the next boot.

## Caveats

- The PSK lives **plaintext** on the system partition. Fine for a dev kit;
  not for production.
- Requires `userdebug` (the service runs in the `shell` domain via
  `seclabel u:r:shell:s0`). On `user` builds the `seclabel` directive will
  be rejected and the service won't start.
- The script runs after `sys.boot_completed=1`, so WifiService is up by
  the time `cmd wifi` is invoked. There's no retry loop — if Wi-Fi happens
  to be in a transient state, the seed is still recorded as done. Delete
  the marker and reboot to retry.

## Files

```
device/gborges/common/wifi-seed/
├── Android.bp                  sh_binary (script + its init_rc)
├── README.md                   this file
├── gborges-wifi-seed.rc        init service (boot_completed → start)
├── gborges-wifi-seed.sh        the seeding script
├── wifi.conf.example           source-tree template, NOT shipped
├── wifi.conf                   gitignored, conditionally installed
└── .gitignore                  ignores wifi.conf
```
