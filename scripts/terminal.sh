#!/usr/bin/env bash
# Start the terminal emulator chosen in dotfiles.conf (`terminal = ...`).
# Usage: terminal.sh [--float] [command [args...]]
#   --float  window class "tool-float": i3 floats it centered. For short-lived tools
#            started from rofi or polybar (htop, pulsemixer, neomutt, ...).
set -u

DF_TERMINAL=alacritty
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

float=0
[[ "${1:-}" == "--float" ]] && { float=1; shift; }

term=$DF_TERMINAL
command -v "$term" >/dev/null || term=alacritty

args=()
case "$term" in
    alacritty)  (( float )) && args+=(--class tool-float); (( $# )) && args+=(-e "$@") ;;
    kitty)      (( float )) && args+=(--class tool-float); args+=("$@") ;;
    wezterm)    args+=(start); (( float )) && args+=(--class tool-float); (( $# )) && args+=(-- "$@") ;;
    xterm|urxvt) (( float )) && args+=(-class tool-float); (( $# )) && args+=(-e "$@") ;;
    st)         (( float )) && args+=(-c tool-float); (( $# )) && args+=(-e "$@") ;;
esac

exec "$term" "${args[@]}"
