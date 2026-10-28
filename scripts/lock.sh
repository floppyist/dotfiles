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

# Theme from dotfiles.conf (colors as rrggbb, alpha is appended below). The defaults keep
# the lock working when ~/.config/dotfiles/theme.sh is missing or broken.
DF_BG="#191c1c" DF_OVERLAY="#313838" DF_FG="#ebdbb2" DF_SUBTLE="#a89984" DF_MUTED="#7c6f64"
DF_ACCENT="#cc241d" DF_RED="#cc241d" DF_RED_HI="#fb4934" DF_YELLOW_HI="#fabd2f"
DF_FONT="JetBrainsMono Nerd Font" DF_SCALE_PCT=100
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
hex() { local c=${1#\#}; [[ "$c" =~ ^[0-9a-fA-F]{6}$ ]] && printf '%s' "$c" || printf '%s' "$2"; }
BG=$(hex "$DF_BG" 191c1c)
OVERLAY=$(hex "$DF_OVERLAY" 313838)
FG=$(hex "$DF_FG" ebdbb2)
SUBTLE=$(hex "$DF_SUBTLE" a89984)
MUTED=$(hex "$DF_MUTED" 7c6f64)
ACCENT=$(hex "$DF_ACCENT" cc241d)
RED=$(hex "$DF_RED" cc241d)
RED_HI=$(hex "$DF_RED_HI" fb4934)
YELLOW=$(hex "$DF_YELLOW_HI" fabd2f)
FONT=${DF_FONT:-JetBrainsMono Nerd Font}
# dotfiles.conf `scale` in percent: every size below is in logical px, S multiplies (rounded)
S=100
[[ "$DF_SCALE_PCT" =~ ^[0-9]{2,3}$ ]] && (( DF_SCALE_PCT >= 50 && DF_SCALE_PCT <= 400 )) && S=$DF_SCALE_PCT
NONE=00000000

#                 14:05                    clock (always shown, also while verifying)
#           Sunday, 25. October
#
#   ───────────────▂▅█▅▂──────────────     input line: keys light up in the accent,
#                                          white while verifying, red when wrong
#             󰀦  wrong password            status (verify / wrong / caps lock)
#
#        󰌾  user@host  ·  locked           greeter
CENTER="x+w/2"
MID="y+h/2"
ARGS=(
    --color="$BG"
    --ignore-empty-password
    --pass-media-keys
    --pass-volume-keys
    --pass-screen-keys
    # Clock
    --force-clock
    --time-str="%H:%M"
    --date-str="%A, %d. %B"
    --time-font="$FONT"
    --date-font="$FONT"
    --time-size=$(( (72 * S + 50) / 100 ))
    --date-size=$(( (16 * S + 50) / 100 ))
    --time-color="${FG}ff"
    --date-color="${SUBTLE}ff"
    --time-pos="$CENTER:$MID-$(( (24 * S + 50) / 100 ))"
    --date-pos="tx:ty+$(( (40 * S + 50) / 100 ))"
    # Input line instead of the ring: always visible, like the rofi input underline
    --indicator
    --bar-indicator
    --bar-orientation=horizontal
    --bar-direction=2
    --bar-total-width=$(( (480 * S + 50) / 100 ))
    --bar-pos="$CENTER-$(( (240 * S + 50) / 100 )):$MID+$(( (64 * S + 50) / 100 ))"
    --bar-base-width=$(( (2 * S + 50) / 100 ))
    --bar-count=48
    --bar-max-height=$(( (18 * S + 50) / 100 ))
    --bar-step=$(( (4 * S + 50) / 100 ))
    --bar-periodic-step=6
    --bar-color="${OVERLAY}ff"
    --keyhl-color="${ACCENT}ff"
    --bshl-color="${SUBTLE}ff"
    --ringver-color="${FG}ff"
    --ringwrong-color="${RED}ff"
    --ring-color="$NONE"
    --inside-color="$NONE"
    --insidever-color="$NONE"
    --insidewrong-color="$NONE"
    --line-color="$NONE"
    --separator-color="$NONE"
    # Status below the line, worded like the notification headers
    --verif-text="󰌆  verifying"
    --wrong-text="󰀦  wrong password"
    --noinput-text="󰌌  nothing to delete"
    --lock-text="󰌾  locking"
    --lockfailed-text="󰀦  lock failed"
    --verif-font="$FONT"
    --wrong-font="$FONT"
    --verif-size=$(( (14 * S + 50) / 100 ))
    --wrong-size=$(( (14 * S + 50) / 100 ))
    --verif-color="${FG}ff"
    --wrong-color="${RED_HI}ff"
    --verif-pos="$CENTER:$MID+$(( (116 * S + 50) / 100 ))"
    --wrong-pos="$CENTER:$MID+$(( (116 * S + 50) / 100 ))"
    # Caps Lock / Num Lock hint (i3lock-color prints the modifier names)
    --modif-size=$(( (12 * S + 50) / 100 ))
    --modif-color="${YELLOW}ff"
    --modif-pos="$CENTER:$MID+$(( (144 * S + 50) / 100 ))"
    --layout-color="$NONE"
    # Greeter at the bottom
    --greeter-text="󰌾  ${USER:-$(id -un)}@${HOSTNAME:-$(uname -n)}  ·  locked"
    --greeter-font="$FONT"
    --greeter-size=$(( (13 * S + 50) / 100 ))
    --greeter-color="${MUTED}ff"
    --greeter-pos="$CENTER:y+h-$(( (48 * S + 50) / 100 ))"
)

pause_notifications() { command -v dunstctl >/dev/null && dunstctl set-paused "$1"; }
kill_i3lock()         { pkill -xu "$EUID" i3lock; }

lock_failed() {
    # Lost a race against a second lock.sh (e.g. Super+l at the moment the idle lock fires):
    # its i3lock holds the screen, so ours could not grab it. The screen IS locked, and
    # resuming notifications now would show them on top of the lock screen; that instance
    # resumes them when it ends.
    if pgrep -xu "$EUID" i3lock >/dev/null; then
        trap - EXIT
        exit 0
    fi
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
