#!/usr/bin/env bash
# (Re)start polybar on the primary monitor.
# Called by i3 on start/restart and by display-select.sh after a layout change.
set -u

# Stop only our own bars, then wait until they are gone
pkill -u "$UID" -x polybar
for _ in {1..50}; do
    pgrep -u "$UID" -x polybar >/dev/null || break
    sleep 0.1
done

# The volume module (libpulse) crashes the bar on the first scroll when the PulseAudio socket was
# not there at its start: at the first login i3 starts pipewire-pulse at the same moment as the
# bar. Wait for it while pipewire-pulse runs (at most 10 s in all); at once without it.
pulse_ready() {
    [[ -S "${XDG_RUNTIME_DIR:-/nonexistent}/pulse/native" ]] || return 1
    command -v pactl >/dev/null || return 0
    timeout 1 pactl info >/dev/null 2>&1
}
end=$(( SECONDS + 10 ))
while (( SECONDS < end )) && ! pulse_ready; do
    # i3 starts it just before this script: give it a moment to appear
    (( SECONDS >= end - 9 )) && ! pgrep -u "$UID" -x pipewire-pulse >/dev/null && break
    sleep 0.2
done

# Primary output, else the first connected one
MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: '/\(primary\)/ {print $1; exit}')
[[ -z "$MONITOR" ]] && MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: 'NR == 1 {print $1}')
export MONITOR

polybar main >/dev/null 2>&1 &
disown
