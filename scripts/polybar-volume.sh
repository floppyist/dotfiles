#!/usr/bin/env bash
# Volume capsule for polybar: "<icon>  55%", muted "󰝟  mute"; nothing without a sound server
# or output (the capsule hides itself). pactl talks to PulseAudio and to PipeWire's pulse server.
# Usage: polybar-volume.sh --status   one status line
#        polybar-volume.sh --events   one line per sink/server change (polybar-watch event source)
# volume.sh pushes the new text to the capsule itself (polybar-watch --push volume), so a key
# shows at once; the events catch changes made elsewhere (pulsemixer, other programs).
set -u

DF_BLUE_HI="#83a598" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
# volume_text, volume_read
# shellcheck source=lib/volume.sh
. "$(dirname "$(readlink -f "$0")")/lib/volume.sh" || exit 1

# pactl translates its output
export LC_ALL=C

status() {
    if volume_read; then volume_text "$VOL" "$MUTE"; else echo ""; fi
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
