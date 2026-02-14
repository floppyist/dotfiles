#!/usr/bin/env bash

INTERNAL="eDP"

EXTERNALS=$(xrandr | grep " connected" | grep -v "$INTERNAL" | cut -d" " -f1)

if [ -z "$EXTERNALS" ]; then
    notify-send "Display" "No external display found."
    exit 1
fi

CHOICE=$(echo -e "$EXTERNALS\nOFF" | rofi -dmenu -p "Choose display:")

if [ -z "$CHOICE" ]; then
    exit 0
fi

if [ "$CHOICE" == "OFF" ]; then
    for m in $EXTERNALS; do
        xrandr --output "$m" --off
    done
    notify-send "Display" "Externe displays deactivated."
else
    xrandr --output "$INTERNAL" --auto --primary --output "$CHOICE" --auto --right-of "$INTERNAL"
    notify-send "Display" "$CHOICE was activated as extension"
fi
