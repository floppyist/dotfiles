#!/usr/bin/env bash
# Volume keys and the volume capsule, with an on-screen bar (dunst progress bar, replaces itself
# while you press). pactl works with PipeWire (pipewire-pulse) and PulseAudio.
# Usage: volume.sh up|down|mute|mic
set -u

STEP=5          # percent
MAX=100         # never louder than 100 % (above that the sound clips)

# pactl translates its output
export LC_ALL=C

# osd TAG SUMMARY [VALUE]
osd() {
    local hints=(-h "string:x-dunst-stack-tag:$1")
    [[ -n "${3:-}" ]] && hints+=(-h "int:value:$3")
    notify-send -a osd -u low "${hints[@]}" "$2" >/dev/null 2>&1
}

# Volume of the default output in percent (the loudest channel) -> VOL
get_volume() {
    local out pct
    VOL=-1
    out=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null) || return 1
    for pct in $(grep -o '[0-9]\+%' <<< "$out"); do
        pct=${pct%\%}
        (( 10#$pct > VOL )) && VOL=$(( 10#$pct ))
    done
    (( VOL >= 0 ))
}

muted() { [[ $(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null) == *yes* ]]; }

case "${1:-}" in
    up|down)
        get_volume || { osd volume "󰝟  No audio output"; exit 1; }
        if [[ $1 == up ]]; then
            new=$(( (VOL / STEP + 1) * STEP ))
            (( new > MAX )) && new=$MAX
        else
            new=$(( (VOL + STEP - 1) / STEP * STEP - STEP ))
            (( new < 0 )) && new=0
        fi
        # sets every channel to the same value (a balance set elsewhere is reset)
        pactl set-sink-volume @DEFAULT_SINK@ "$new%"
        ;;
    mute)
        pactl set-sink-mute @DEFAULT_SINK@ toggle
        ;;
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

get_volume || exit 1
if muted; then
    osd volume "󰝟  Muted" 0
elif (( VOL >= 66 )); then
    osd volume "󰕾  Volume  $VOL%" "$VOL"
elif (( VOL >= 33 )); then
    osd volume "󰖀  Volume  $VOL%" "$VOL"
else
    osd volume "󰕿  Volume  $VOL%" "$VOL"
fi
