#!/usr/bin/env bash
# Volume keys and the volume capsule, with an on-screen bar (dunst progress bar, replaces itself
# while you press). pactl works with PipeWire (pipewire-pulse) and PulseAudio.
# Usage: volume.sh up|down|mute|mic
#
# Fast enough for a held key (X repeats it 25 times a second): the new value goes to the capsule
# before the sound server is asked (polybar-watch --push volume), the on-screen bar runs in the
# background, and while a key is held the volume is taken from the last press instead of asking
# the server again. One press at a time (flock): presses that overlap would read the same value.
set -u

STEP=5          # percent
MAX=100         # never louder than 100 % (above that the sound clips)
FRESH_US=1500000    # the last press's value counts for 1.5 s

DF_BLUE_HI="#83a598" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
# volume_text, volume_read, private_run
# shellcheck source=lib/volume.sh
. "$(dirname "$(readlink -f "$0")")/lib/volume.sh" || exit 1

# pactl translates its output
export LC_ALL=C

# osd TAG SUMMARY [VALUE]: in the background, nobody waits for dunst
osd() {
    local hints=(-h "string:x-dunst-stack-tag:$1")
    [[ -n "${3:-}" ]] && hints+=(-h "int:value:$3")
    notify-send -a osd -u low "${hints[@]}" "$2" >/dev/null 2>&1 9>&- &
}

osd_volume() {
    if [[ $2 == yes ]]; then
        osd volume "󰝟  Muted" 0
    elif (( $1 >= 66 )); then
        osd volume "󰕾  Volume  $1%" "$1"
    elif (( $1 >= 33 )); then
        osd volume "󰖀  Volume  $1%" "$1"
    else
        osd volume "󰕿  Volume  $1%" "$1"
    fi
}

# the new text straight into the capsule (if the bar runs); <> never blocks on a FIFO
push() {
    local fifo=${XDG_RUNTIME_DIR:-}/polybar-push/volume fd
    [[ -n ${XDG_RUNTIME_DIR:-} && -p $fifo && -O $fifo ]] || return 0
    exec {fd}<>"$fifo" || return 0
    printf '@@show %s\n' "$(volume_text "$1" "$2")" >&"$fd"
    exec {fd}<&-
}

now_us() { local t=${EPOCHREALTIME/[.,]/}; printf -v NOW '%d' "$((10#$t))"; }

case "${1:-}" in
    up|down|mute) ;;
    mic)
        pactl set-source-mute @DEFAULT_SOURCE@ toggle
        if [[ $(pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null) == *yes* ]]; then
            osd mic "󰍭  Microphone muted"
        else
            osd mic "󰍬  Microphone on"
        fi
        exit 0
        ;;
    *) echo "usage: volume.sh up|down|mute|mic" >&2; exit 2 ;;
esac

private_run volume || exit 1
exec 9>>"$RUN/volume.lock"
flock 9

# "VOLUME MUTE TIME" of the last press
state=$RUN/volume.state
VOL="" MUTE="" t=0
read -r VOL MUTE t 2>/dev/null < "$state"
now_us
if ! [[ $VOL =~ ^[0-9]+$ && $MUTE =~ ^(yes|no)$ && $t =~ ^[0-9]+$ ]] || (( NOW - t > FRESH_US )); then
    volume_read || { osd volume "󰝟  No audio output"; exit 1; }
fi

case $1 in
    up)
        VOL=$(( (VOL / STEP + 1) * STEP ))
        (( VOL > MAX )) && VOL=$MAX ;;
    down)
        VOL=$(( (VOL + STEP - 1) / STEP * STEP - STEP ))
        (( VOL < 0 )) && VOL=0 ;;
    mute)
        [[ $MUTE == yes ]] && MUTE=no || MUTE=yes ;;
esac

push "$VOL" "$MUTE"
osd_volume "$VOL" "$MUTE"
if [[ $1 == mute ]]; then
    [[ $MUTE == yes ]] && pactl set-sink-mute @DEFAULT_SINK@ 1 || pactl set-sink-mute @DEFAULT_SINK@ 0
else
    # sets every channel to the same value (a balance set elsewhere is reset)
    pactl set-sink-volume @DEFAULT_SINK@ "$VOL%"
fi
now_us
printf '%s %s %s\n' "$VOL" "$MUTE" "$NOW" > "$state"
