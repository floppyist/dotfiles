#!/usr/bin/env bash
# Choose how to use an external display (rofi menu)
set -u

notify() { notify-send "Display" "$1"; }

command -v rofi >/dev/null || { notify "rofi not found"; exit 1; }

# Internal panel: first eDP/LVDS output (override with INTERNAL=...)
INTERNAL="${INTERNAL:-$(xrandr | awk '/^(eDP|LVDS)/ {print $1; exit}')}"

mapfile -t EXTERNALS < <(xrandr | awk -v internal="$INTERNAL" '$2 == "connected" && $1 != internal {print $1}')

if (( ${#EXTERNALS[@]} == 0 )); then
    notify "No external display found."
    exit 1
fi

MENU=()
for m in "${EXTERNALS[@]}"; do
    MENU+=("$m: extend right" "$m: extend left" "$m: mirror" "$m: only external")
done
MENU+=("OFF")

CHOICE=$(printf '%s\n' "${MENU[@]}" | rofi -dmenu -i -p "Display")
[[ -z "$CHOICE" ]] && exit 0

if [[ "$CHOICE" == "OFF" ]]; then
    args=(--output "$INTERNAL" --auto --primary)
    for m in "${EXTERNALS[@]}"; do
        args+=(--output "$m" --off)
    done
    xrandr "${args[@]}" && notify "External displays deactivated."
    exit 0
fi

OUT="${CHOICE%%: *}"
MODE="${CHOICE#*: }"

case "$MODE" in
    "extend right")  args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --right-of "$INTERNAL") ;;
    "extend left")   args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --left-of "$INTERNAL") ;;
    "mirror")        args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --same-as "$INTERNAL") ;;
    "only external") args=(--output "$OUT" --auto --primary --output "$INTERNAL" --off) ;;
    *) exit 1 ;;
esac

if xrandr "${args[@]}"; then
    notify "$OUT: $MODE"
else
    notify-send -u critical "Display" "xrandr failed for $OUT ($MODE)"
    exit 1
fi
