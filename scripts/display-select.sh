#!/usr/bin/env bash
# Windows-style display menu (Super+p): choose how to use an external display.
# "Second screen only" turns the internal panel off; it must be confirmed within
# 15 s, otherwise the change is reverted (a dark external screen cannot lock you out).
# "Arrange" (and Super+Shift+p) opens `displays`: resolution, rate, position, rotation.
# The chosen layout is remembered for these monitors (`displays save`); `displays preset` builds
# it, so every monitor keeps its own scale.
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

# The layouts are built by `displays`, so every monitor keeps its own scale (other external
# displays are turned off)
case "$MODE" in
    "PC screen only")     preset=(internal "$OUT") ;;
    "Duplicate")          preset=(mirror "$OUT") ;;
    "Extend")             preset=(extend "$OUT") ;;
    "Second screen only") preset=(external "$OUT") ;;
    *) exit 1 ;;
esac
# Remember the layout for these monitors, then re-place the bar and the wallpaper and
# (scale = auto) set the desktop scale for the monitors
refresh_desktop() {
    "$DISPLAYS" save >/dev/null 2>&1
    "$HERE/dotfiles" apply --layout >/dev/null 2>&1
}

if ! err=$("$DISPLAYS" preset "${preset[@]}" 2>&1); then
    notify -u critical "Display" "$MODE failed: ${err#displays: }"
    exit 1
fi

if [[ "$MODE" == "Second screen only" ]]; then
    # "Revert" first: it is preselected, so a blind Enter is the safe choice
    ANSWER=$(printf '%s\n' "󰕌  Revert" "󰄬  Keep this layout" |
        timeout 15 "$ROFI_MENU" "display" "Reverting in 15 s unless confirmed") || ANSWER=0
    if [[ "$ANSWER" != 1 ]]; then
        "$DISPLAYS" preset internal "$OUT" >/dev/null 2>&1
        refresh_desktop
        notify "Layout reverted" "$INTERNAL is active again"
        exit 0
    fi
fi

refresh_desktop
notify "$MODE" "$INTERNAL  ·  $OUT"
