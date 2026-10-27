#!/usr/bin/env bash
# Screenshot (Print) or selected region (Shift+Print).
# Saved as ~/images/screenshots/screenshot_NNN.png and copied to the clipboard.
# Usage: screenshot.sh [--select]
set -u

TARGET_DIR="$HOME/images/screenshots"
PREFIX="screenshot_"

notify() { notify-send -a screenshot "$@" >/dev/null 2>&1; }

select=0
[[ "${1:-}" == "--select" ]] && select=1

if (( select )); then
    # One selection at a time (a second Shift+Print while choosing does nothing)
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/screenshot-select.lock"
    flock -n 9 || exit 0
    tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/screenshot.XXXXXX") || exit 1
    trap 'rm -rf "$tmp"' EXIT
fi

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

if (( select )); then
    # Freeze: capture the whole screen first, then choose the region on that picture (snip
    # shows it dimmed, with a hint bar; drag = region, click = window, Esc = cancel).
    # timeout: never leave the pointer and keyboard grabbed if snip hangs.
    if ! scrot -z "$tmp/full.png"; then
        notify -u critical "Screenshot failed" "scrot could not capture the screen"
        exit 1
    fi
    timeout 300 "$(dirname "$(readlink -f "$0")")/snip" "$tmp/full.png" "$FILE_PATH" 2>"$tmp/err"
    rc=$?
    exec 9>&-      # release the lock (xclip below stays in the background and would keep it)
    case $rc in
        0) ;;
        1) exit 0 ;;   # cancelled
        124) notify -u critical "Screenshot cancelled" "no region chosen within 5 minutes"; exit 1 ;;
        *) err=$(tail -n 1 "$tmp/err" 2>/dev/null)
           notify -u critical "Screenshot failed" "${err:-region selection did not start}"
           exit 1 ;;
    esac
elif ! scrot -z "$FILE_PATH"; then
    notify -u critical "Screenshot failed" "scrot could not capture the screen"
    exit 1
fi

clip=""
if command -v xclip >/dev/null && xclip -selection clipboard -t image/png -i "$FILE_PATH" 2>/dev/null; then
    clip="  ·  copied"
fi

notify "Screenshot saved" "$FILENAME$clip"
