#!/usr/bin/env bash
# Lock the screen with i3lock-color.
#
# Called directly (Super+l) and by xss-lock (idle timeout, suspend, loginctl lock-session).
# - With `xss-lock --transfer-sleep-lock`, the sleep delay is released only after the
#   screen is locked, so no screen content is visible on resume.
# - If i3lock-color fails to start (e.g. unknown option), plain i3lock is used.
#   If that fails too, a critical notification says so: the screen is NOT locked.
# - Notifications are paused while locked (content stays hidden) and resumed on every exit path.
set -u

pgrep -xu "$EUID" i3lock >/dev/null && exit 0

BG=191c1c
FG=ebdbb2
DIM=a89984
RED=cc241d
FONT="JetBrainsMono Nerd Font"

ARGS=(
    --color="$BG"
    --ignore-empty-password
    --pass-media-keys
    --pass-volume-keys
    --pass-screen-keys
    # Indicator: invisible until you type, then a thin red ring
    --indicator
    --radius=150
    --ring-width=6
    --inside-color=00000000
    --ring-color=00000000
    --line-color=00000000
    --separator-color=00000000
    --insidever-color=00000000
    --insidewrong-color=00000000
    --ringver-color="${FG}ff"
    --ringwrong-color="${RED}ff"
    --keyhl-color="${RED}ff"
    --bshl-color="${DIM}ff"
    # Clock
    --clock
    --time-str="%H:%M"
    --date-str="%A, %d. %B %Y"
    --time-font="$FONT"
    --date-font="$FONT"
    --time-size=72
    --date-size=16
    --time-color="${FG}ff"
    --date-color="${DIM}ff"
    --date-pos="tx:ty+44"
    # Status texts
    --verif-text="authenticating…"
    --wrong-text="access denied"
    --noinput-text="no input"
    --lock-text="locking…"
    --lockfailed-text="lock failed"
    --verif-font="$FONT"
    --wrong-font="$FONT"
    --verif-size=14
    --wrong-size=14
    --verif-color="${FG}ff"
    --wrong-color="${RED}ff"
    --layout-color=00000000
    # Greeter at the bottom
    --greeter-text="  ${USER:-$(id -un)}@${HOSTNAME:-$(uname -n)}  ·  session locked"
    --greeter-font="$FONT"
    --greeter-size=13
    --greeter-color="${DIM}ff"
    --greeter-pos="x+w/2:y+h-48"
)

pause_notifications() { command -v dunstctl >/dev/null && dunstctl set-paused "$1"; }
kill_i3lock()         { pkill -xu "$EUID" i3lock; }

lock_failed() {
    pause_notifications false
    notify-send -a system -u critical "Lock failed" "i3lock could not start. The screen is NOT locked." >/dev/null 2>&1
    exit 1
}

trap 'pause_notifications false' EXIT
# xss-lock kills the locker when the session is unlocked from outside (loginctl unlock-session)
trap 'kill_i3lock; exit 0' TERM INT HUP

pause_notifications true

if [[ -e /dev/fd/${XSS_SLEEP_LOCK_FD:--1} ]]; then
    # Suspend: i3lock forks once the screen is locked, then the sleep delay lock is released.
    i3lock "${ARGS[@]}" {XSS_SLEEP_LOCK_FD}<&- ||
        i3lock --color="$BG" {XSS_SLEEP_LOCK_FD}<&- ||
        lock_failed
    exec {XSS_SLEEP_LOCK_FD}<&-
    while pgrep -xu "$EUID" i3lock >/dev/null; do sleep 1; done
else
    # Run in the background and wait, so the TERM trap fires immediately
    i3lock --nofork "${ARGS[@]}" &
    wait $!
    rc=$?
    # 1..127: i3lock exited with an error before locking (no unlock, no signal)
    if (( rc > 0 && rc < 128 )); then
        i3lock --nofork --color="$BG" &
        wait $!
        rc=$?
        (( rc > 0 && rc < 128 )) && lock_failed
    fi
fi

exit 0
