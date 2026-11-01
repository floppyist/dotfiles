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
# bar. Wait for it (at most 10 s; not at all without pipewire-pulse, and instantly on a restart).
if command -v pipewire-pulse >/dev/null; then
    for _ in {1..100}; do
        if [[ -S "${XDG_RUNTIME_DIR:-/nonexistent}/pulse/native" ]] &&
           { ! command -v pactl >/dev/null || timeout 2 pactl info >/dev/null 2>&1; }; then
            break
        fi
        sleep 0.1
    done
fi

# Primary output, else the first connected one
MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: '/\(primary\)/ {print $1; exit}')
[[ -z "$MONITOR" ]] && MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: 'NR == 1 {print $1}')
export MONITOR

polybar main >/dev/null 2>&1 &
disown
