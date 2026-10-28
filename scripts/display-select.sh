#!/usr/bin/env bash
# Windows-style display menu (Super+p): choose how to use an external display.
# "Second screen only" turns the internal panel off; it must be confirmed within
# 15 s, otherwise the change is reverted (a dark external screen cannot lock you out).
# "Arrange" (and Super+Shift+p) opens `displays`: resolution, rate, position, rotation.
# The chosen layout is remembered for these monitors (`displays save`).
set -u

# Helpers next to this script (works without ~/.local/bin in PATH)
HERE="$(dirname "$(readlink -f "$0")")"
ROFI_MENU="$HERE/rofi-menu"
DISPLAYS="$HERE/displays"

notify() { notify-send -a display "$@" >/dev/null 2>&1; }

command -v rofi >/dev/null || { notify -u critical "Display" "rofi not found"; exit 1; }

# Internal panel: first eDP/LVDS output (override with INTERNAL=...)
INTERNAL="${INTERNAL:-$(xrandr | awk '/^(eDP|LVDS)/ {print $1; exit}')}"
[[ -n "$INTERNAL" ]] || { notify -u critical "Display" "No internal panel found (set INTERNAL=...)"; exit 1; }

mapfile -t EXTERNALS < <(xrandr | awk -v internal="$INTERNAL" '$2 == "connected" && $1 != internal {print $1}')

# Nothing to choose between: the arrange menu still sets resolution and rotation
(( ${#EXTERNALS[@]} == 0 )) && exec "$DISPLAYS"

# With several external displays, pick one first
OUT="${EXTERNALS[0]}"
if (( ${#EXTERNALS[@]} > 1 )); then
    IDX=$(printf '%s\n' "${EXTERNALS[@]}" | "$ROFI_MENU" "display" "select output") || exit 0
    OUT="${EXTERNALS[$IDX]}"
fi

MODES=("PC screen only" "Duplicate" "Extend" "Second screen only" "Arrange")
ICONS=("󰌢" "󰆑" "󰡎" "󰍹" "󰁌")   # md-laptop, md-content_duplicate, md-arrow_expand_horizontal, md-monitor,
                                 # md-arrow_expand_all
LABELS=()
for i in "${!MODES[@]}"; do LABELS+=("${ICONS[$i]}  ${MODES[$i]}"); done

IDX=$(printf '%s\n' "${LABELS[@]}" | "$ROFI_MENU" "display" "$INTERNAL  ·  $OUT") || exit 0
MODE="${MODES[$IDX]}"
[[ "$MODE" == "Arrange" ]] && exec "$DISPLAYS"

# Keep all other external displays off
others=()
for m in "${EXTERNALS[@]}"; do
    [[ "$m" != "$OUT" ]] && others+=(--output "$m" --off)
done

internal_only=(--output "$INTERNAL" --auto --primary --output "$OUT" --off "${others[@]}")

case "$MODE" in
    "PC screen only")     args=("${internal_only[@]}") ;;
    "Duplicate")          args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --same-as "$INTERNAL" "${others[@]}") ;;
    "Extend")             args=(--output "$INTERNAL" --auto --primary --output "$OUT" --auto --right-of "$INTERNAL" "${others[@]}") ;;
    "Second screen only") args=(--output "$OUT" --auto --primary --output "$INTERNAL" --off "${others[@]}") ;;
    *) exit 1 ;;
esac

# Remember the layout for these monitors, then re-place the bar and the wallpaper and
# (scale = auto) scale the desktop for the primary monitor
refresh_desktop() {
    "$DISPLAYS" save >/dev/null 2>&1
    "$HERE/dotfiles" apply --layout >/dev/null 2>&1
}

if ! xrandr "${args[@]}"; then
    notify -u critical "Display" "xrandr failed for $OUT ($MODE)"
    exit 1
fi

if [[ "$MODE" == "Second screen only" ]]; then
    # "Revert" first: it is preselected, so a blind Enter is the safe choice
    ANSWER=$(printf '%s\n' "󰕌  Revert" "󰄬  Keep this layout" |
        timeout 15 "$ROFI_MENU" "display" "Reverting in 15 s unless confirmed") || ANSWER=0
    if [[ "$ANSWER" != 1 ]]; then
        xrandr "${internal_only[@]}"
        refresh_desktop
        notify "Layout reverted" "$INTERNAL is active again"
        exit 0
    fi
fi

refresh_desktop
notify "$MODE" "$INTERNAL  ·  $OUT"
