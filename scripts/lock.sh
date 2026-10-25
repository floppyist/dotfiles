#!/bin/bash
# Lock the screen with i3lock.
# Notifications are paused while locked (so their content stays hidden) and
# resumed on every exit path, including signals.

pgrep -x i3lock >/dev/null && exit 0

resume_notifications() {
    command -v dunstctl >/dev/null && dunstctl set-paused false
}
trap resume_notifications EXIT
trap 'exit 1' INT TERM HUP

command -v dunstctl >/dev/null && dunstctl set-paused true

i3lock --nofork \
-c 191c1c \
--ignore-empty-password \
--pass-media-keys \
--pass-volume-keys \
--inside-color=00000000 \
--ring-color=00000000 \
--line-color=00000000 \
--separator-color=00000000 \
--keyhl-color=cc241dff \
--bshl-color=cc241dff \
--insidever-color=00000000 \
--ringver-color=cc241dff \
--insidewrong-color=00000000 \
--ringwrong-color=cc241dff \
--time-color=a89984 \
--date-color=a89984 \
--verif-color=00000000 \
--wrong-color=00000000 \
--layout-color=00000000 \
--noinput-text="" \
--clock \
--indicator \
--time-str="%H:%M" \
--date-str="%A, %d. %B %Y" \
--time-font="JetBrainsMono Nerd Font Bold" \
--date-font="JetBrainsMono Nerd Font Bold" \
--time-size=46 \
--date-size=16 \
--radius 160 \
--ring-width 32
