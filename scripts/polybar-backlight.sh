#!/usr/bin/env bash
# Backlight in 5 % steps (polybar ipc module + brightness keys with on-screen bar)
# Usage: polybar-backlight.sh [up|down]   (no argument: print the current percentage)
set -u

# First available backlight device (e.g. amdgpu_bl0, intel_backlight)
shopt -s nullglob
BACKLIGHTS=(/sys/class/backlight/*)
SYSFS="${BACKLIGHTS[0]:-}"
[[ -d "$SYSFS" ]] || { echo "n/a"; exit 0; }

read -r CURR < "$SYSFS/brightness"
read -r MAX < "$SYSFS/max_brightness"
(( MAX > 0 )) || { echo "n/a"; exit 0; }

PCT=$(( (CURR * 100 + MAX / 2) / MAX ))

set_pct() {
    local pct=$1 val
    val=$(( (pct * MAX + 50) / 100 ))
    # Direct write needs the udev rule (group video); brightnessctl is the fallback
    { echo "$val" > "$SYSFS/brightness"; } 2>/dev/null || brightnessctl -q set "$val"
    polybar-msg action backlight hook 0 >/dev/null 2>&1 &
    notify-send -a osd -u low -h string:x-dunst-stack-tag:brightness -h "int:value:$pct" \
        "󰃠  Brightness  $pct%" >/dev/null 2>&1
}

case "${1:-}" in
    up)
        NEW=$(( (PCT / 5 + 1) * 5 ))
        (( NEW > 100 )) && NEW=100
        set_pct "$NEW"
        ;;
    down)
        NEW=$(( ((PCT - 1) / 5) * 5 ))
        # Never switch the panel fully off with the keys
        (( NEW < 5 )) && NEW=5
        set_pct "$NEW"
        ;;
    *)
        echo "${PCT}%"
        ;;
esac
