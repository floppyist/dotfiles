#!/usr/bin/env bash

SYSFS="/sys/class/backlight/amdgpu_bl0"

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
