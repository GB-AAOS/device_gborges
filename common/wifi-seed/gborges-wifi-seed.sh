#!/system/bin/sh
# Seed Wi-Fi networks on first boot if /system/etc/gborges/wifi.conf is
# present. See device/gborges/common/wifi-seed/README.md.

CONF=/system/etc/gborges/wifi.conf
MARKER=/data/local/tmp/.gborges-wifi-seeded
TAG=gborges-wifi-seed

logmsg() { /system/bin/log -t "$TAG" "$@"; }

if [ ! -f "$CONF" ]; then
    logmsg "no $CONF; nothing to seed"
    exit 0
fi

if [ -f "$MARKER" ]; then
    logmsg "already seeded ($MARKER); skip"
    exit 0
fi

# shellcheck source=/dev/null
. "$CONF"

added=0
i=1
while :; do
    eval "ssid=\${SSID_$i:-}"
    [ -n "$ssid" ] || break

    eval "psk=\${PSK_$i:-}"
    eval "security=\${SECURITY_$i:-wpa2}"
    eval "hidden=\${HIDDEN_$i:-0}"

    hidden_flag=""
    [ "$hidden" = "1" ] && hidden_flag="-h"

    case "$security" in
        open)
            if cmd wifi add-network "$ssid" open $hidden_flag; then
                added=$((added + 1))
                logmsg "added SSID_$i=$ssid security=open"
            else
                logmsg "add failed: SSID_$i=$ssid"
            fi
            ;;
        wpa2|wpa3)
            if [ -z "$psk" ]; then
                logmsg "PSK_$i empty for SECURITY_$i=$security; skip"
            elif cmd wifi add-network "$ssid" "$security" "$psk" $hidden_flag; then
                added=$((added + 1))
                logmsg "added SSID_$i=$ssid security=$security"
            else
                logmsg "add failed: SSID_$i=$ssid"
            fi
            ;;
        *)
            logmsg "unknown SECURITY_$i=$security; skip"
            ;;
    esac

    i=$((i + 1))
done

logmsg "seeded $added network(s)"

if [ "$added" -gt 0 ]; then
    # Force Wi-Fi on. The def_wifi_on=true static overlay only seeds the
    # settings DB on first create; a system-only reflash preserves /data,
    # so a previously-persisted WIFI_ON=0 wins on later boots. Flip it
    # here so freshly-seeded networks can actually auto-join. The marker
    # gates this to a one-shot — the user can still turn Wi-Fi off later
    # via Settings without the script fighting them on the next boot.
    cmd wifi set-wifi-enabled enabled >/dev/null 2>&1 \
        || logmsg "set-wifi-enabled failed (non-fatal)"

    # Kick an immediate scan so auto-join doesn't wait for the next
    # periodic tick.
    cmd wifi start-scan >/dev/null 2>&1 \
        || logmsg "start-scan failed (non-fatal)"
fi

touch "$MARKER"
