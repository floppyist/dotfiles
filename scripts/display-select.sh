#!/usr/bin/env bash
# Windows-style display menu (WIN+P): choose how to use external displays
set -u

THEME="$HOME/.config/rofi/config.rasi"

notify() { notify-send "Display" "$1" >/dev/null 2>&1; }

command -v rofi >/dev/null || { notify "rofi not found"; exit 1; }

# Internal panel: first eDP/LVDS output (override with INTERNAL=...)
INTERNAL="${INTERNAL:-$(xrandr | awk '/^(eDP|LVDS)/ {print $1; exit}')}"

mapfile -t EXTERNALS < <(xrandr | awk -v internal="$INTERNAL" '$2 == "connected" && $1 != internal {print $1}')

if (( ${#EXTERNALS[@]} == 0 )); then
    notify "No external display found."
    exit 1
fi

rofi_menu() {
    rofi -dmenu -i -format i -theme "$THEME" -mesg "$1" -p "Display" \
        -theme-str 'window { width: 30%; }' \
        -theme-str 'listview { lines: 10; }'
}

# With several external displays, pick one first
OUT="${EXTERNALS[0]}"
if (( ${#EXTERNALS[@]} > 1 )); then
    IDX=$(printf '%s\n' "${EXTERNALS[@]}" | rofi_menu "SELECT DISPLAY")
    [[ -z "$IDX" ]] && exit 0
    OUT="${EXTERNALS[$IDX]}"
fi

MODES=("PC screen only" "Duplicate" "Extend" "Second screen only")
IDX=$(printf '%s\n' "${MODES[@]}" | rofi_menu "$OUT")
[[ -z "$IDX" ]] && exit 0
LABEL="${MODES[$IDX]}"

# Keep all other external displays off
others=()
for m in "${EXTERNALS[@]}"; do
    [[ "$m" != "$OUT" ]] && others+=(--output "$m" --off)
done

case "$LABEL" in
    "PC screen only")      args=(--output "$INTERNAL" --auto --primary --output "$OUT" --off) ;;
    "Duplicate")           args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --same-as "$INTERNAL") ;;
    "Extend")              args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --right-of "$INTERNAL") ;;
    "Second screen only")  args=(--output "$OUT" --auto --primary --output "$INTERNAL" --off) ;;
    *) exit 1 ;;
esac
args+=("${others[@]}")

if xrandr "${args[@]}"; then
    notify "$OUT: $LABEL"
else
    notify-send -u critical "Display" "xrandr failed for $OUT ($LABEL)"
    exit 1
fi
