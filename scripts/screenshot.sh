#!/usr/bin/env bash
# Screenshot (Print) or selected region (Shift+Print).
# Saved as ~/images/screenshots/screenshot_NNN.png and copied to the clipboard.
# Usage: screenshot.sh [--select]
set -u

TARGET_DIR="$HOME/images/screenshots"
PREFIX="screenshot_"

notify() { notify-send -a screenshot "$@" >/dev/null 2>&1; }

# Selection frame in the accent color from dotfiles.conf
DF_ACCENT="#cc241d"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

mkdir -p "$TARGET_DIR"

# Next free number (highest existing + 1)
shopt -s nullglob
max=-1
for f in "$TARGET_DIR/$PREFIX"*.png; do
    n=${f##*/"$PREFIX"}; n=${n%.png}
    [[ "$n" =~ ^[0-9]+$ ]] && (( 10#$n > max )) && max=$(( 10#$n ))
done
FILENAME=$(printf '%s%03d.png' "$PREFIX" $(( max + 1 )))
FILE_PATH="$TARGET_DIR/$FILENAME"

args=(-z)
[[ "${1:-}" == "--select" ]] && args+=(--select --freeze --line mode=edge,width=2,color="$DF_ACCENT")

if ! scrot "${args[@]}" "$FILE_PATH"; then
    # Esc during region selection is not an error
    [[ "${1:-}" == "--select" ]] && exit 0
    notify -u critical "Screenshot failed" "scrot could not capture the screen"
    exit 1
fi

clip=""
if command -v xclip >/dev/null && xclip -selection clipboard -t image/png -i "$FILE_PATH" 2>/dev/null; then
    clip="  ·  copied"
fi

notify "Screenshot saved" "$FILENAME$clip"
