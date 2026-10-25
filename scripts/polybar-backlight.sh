#!/usr/bin/env bash

# First available backlight device (e.g. amdgpu_bl0, intel_backlight)
shopt -s nullglob
BACKLIGHTS=(/sys/class/backlight/*)
SYSFS="${BACKLIGHTS[0]:-}"
[[ -d "$SYSFS" ]] || { echo "no backlight device" >&2; exit 1; }

read -r CURR < "$SYSFS/brightness"
read -r MAX < "$SYSFS/max_brightness"

PCT=$(( (CURR * 100 + MAX / 2) / MAX ))

case "$1" in
    up)
        NEW_PCT=$(( (PCT / 5 + 1) * 5 ))
        (( NEW_PCT > 100 )) && NEW_PCT=100
        NEW_VAL=$(( (NEW_PCT * MAX + 50) / 100 ))

        echo "$NEW_VAL" > "$SYSFS/brightness" 2>/dev/null || brightnessctl -q set "$NEW_VAL"
        polybar-msg hook backlight 1 >/dev/null 2>&1 &
        ;;
    down)
        NEW_PCT=$(( ((PCT - 1) / 5) * 5 ))
        (( NEW_PCT < 0 )) && NEW_PCT=0
        NEW_VAL=$(( (NEW_PCT * MAX + 50) / 100 ))

        echo "$NEW_VAL" > "$SYSFS/brightness" 2>/dev/null || brightnessctl -q set "$NEW_VAL"
        polybar-msg hook backlight 1 >/dev/null 2>&1 &
        ;;
    *)
        echo "${PCT}%"
        ;;
esac
