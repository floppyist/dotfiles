#!/bin/bash

TARGET_DIR="$HOME/images/screenshots"
PREFIX="screenshot_"

mkdir -p "$TARGET_DIR"

MAX_NUM=$(ls -1 "$TARGET_DIR" 2>/dev/null | grep -oP "^${PREFIX}\K\d+" | sort -n | tail -1)

if [ -z "$MAX_NUM" ]; then
    NEXT_NUM=0
else
    NEXT_NUM=$((10#$MAX_NUM + 1))
fi

FILENAME=$(printf "%s%03d.png" "$PREFIX" "$NEXT_NUM")
FILE_PATH="$TARGET_DIR/$FILENAME"

if /usr/bin/scrot -z "$FILE_PATH"; then
    notify-send "Screenshot Captured" \
                "Saved as: <b>$FILENAME</b>" \
                -i camera-photo \
                -a "i3-Screenshot" \
                -t 3000
else
    notify-send "❌ Error" "Failed to save screenshot." -u critical
fi
