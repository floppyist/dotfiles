#!/usr/bin/env bash
# Volume keys with an on-screen bar (dunst progress bar, replaces itself while you press).
# Usage: volume.sh up|down|mute|mic
set -u

STEP=5%
SINK=@DEFAULT_AUDIO_SINK@
SOURCE=@DEFAULT_AUDIO_SOURCE@

# osd TAG SUMMARY [VALUE]
osd() {
    local hints=(-h "string:x-dunst-stack-tag:$1")
    [[ -n "${3:-}" ]] && hints+=(-h "int:value:$3")
    notify-send -a osd -u low "${hints[@]}" "$2" >/dev/null 2>&1
}

case "${1:-}" in
    up)   wpctl set-volume -l 1.0 "$SINK" "$STEP+" ;;
    down) wpctl set-volume "$SINK" "$STEP-" ;;
    mute) wpctl set-mute "$SINK" toggle ;;
    mic)
        wpctl set-mute "$SOURCE" toggle
        if wpctl get-volume "$SOURCE" | grep -q MUTED; then
            osd mic "󰍭  Microphone muted"
        else
            osd mic "󰍬  Microphone on"
        fi
        exit 0
        ;;
    *) echo "usage: volume.sh up|down|mute|mic" >&2; exit 2 ;;
esac

# "Volume: 0.56" or "Volume: 0.56 [MUTED]"
out=$(wpctl get-volume "$SINK" 2>/dev/null) || exit 1
vol=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<< "$out")

if [[ "$out" == *MUTED* ]]; then
    osd volume "󰝟  Muted" 0
elif (( vol >= 66 )); then
    osd volume "󰕾  Volume  $vol%" "$vol"
elif (( vol >= 33 )); then
    osd volume "󰖀  Volume  $vol%" "$vol"
else
    osd volume "󰕿  Volume  $vol%" "$vol"
fi
