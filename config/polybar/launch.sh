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

# Primary output, else the first connected one
MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: '/\(primary\)/ {print $1; exit}')
[[ -z "$MONITOR" ]] && MONITOR=$(polybar --list-monitors 2>/dev/null | awk -F: 'NR == 1 {print $1}')
export MONITOR

polybar main >/dev/null 2>&1 &
disown
