#!/usr/bin/env bash
# Volume capsule for polybar: "<icon>  55%", muted "󰝟  mute"; nothing without a sound server
# or output (the capsule hides itself). pactl talks to PulseAudio and to PipeWire's pulse server.
# Usage: polybar-volume.sh --status   one status line
#        polybar-volume.sh --events   one line per sink/server change (polybar-watch event source)
set -u

DF_BLUE_HI="#83a598" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

# pactl translates its output
export LC_ALL=C

status() {
    local vol mute pct max=-1
    vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null) || { echo ""; return; }
    mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null) || { echo ""; return; }
    # "Volume: front-left: 32770 /  50% / -18.06 dB,   front-right: ...": the loudest channel
    for pct in $(grep -o '[0-9]\+%' <<< "$vol"); do
        pct=${pct%\%}
        (( 10#$pct > max )) && max=$(( 10#$pct ))
    done
    (( max >= 0 )) || { echo ""; return; }
    if [[ $mute == *yes* ]]; then
        echo "%{F$DF_MUTED}󰝟  mute%{F-}"
    elif (( max >= 66 )); then
        echo "%{F$DF_BLUE_HI}󰕾  %{F-}$max%"
    elif (( max >= 33 )); then
        echo "%{F$DF_BLUE_HI}󰖀  %{F-}$max%"
    else
        echo "%{F$DF_BLUE_HI}󰕿  %{F-}$max%"
    fi
}

events() {
    local line src
    # Only sink and server events: every pactl call (the status above, too) is a client that
    # comes and goes, and would trigger the next status run. Stream events (sink-input) do not
    # change the volume of the output.
    exec {src}< <(exec pactl subscribe 2>/dev/null)
    src_pid=$!
    trap 'kill "$src_pid" 2>/dev/null' EXIT
    trap 'exit 0' TERM INT HUP PIPE
    while IFS= read -r line <&"$src"; do
        case $line in
            *" on sink #"*|*" on server"*) printf '%s\n' "$line" ;;
        esac
    done
    # pactl ended (no server yet, or it restarted): polybar-watch starts this again
}

case "${1:-}" in
    --status) status ;;
    --events) events ;;
    *) echo "usage: polybar-volume.sh --status|--events" >&2; exit 2 ;;
esac
