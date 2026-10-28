#!/usr/bin/env bash
# Now playing for the polybar music module (tail = true): "<icon> Title  -mm:ss"
#
# Event-driven: `playerctl --follow` prints a line when the status, the track or the
# position changes. While playing that is once per second (the countdown), while paused
# or stopped nothing at all, so the module costs nothing when no music runs.
#
# Track titles come from websites (browser MPRIS) and media files, so they are untrusted:
# - they go through polybar_safe (lib/polybar.sh).
# - Numbers are validated before bash arithmetic (it evaluates expressions recursively).
set -u

DF_ACCENT="#cc241d" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

# polybar_safe, truncate (next to this script, also without ~/.local/bin in PATH)
# shellcheck source=lib/polybar.sh
. "$(dirname "$(readlink -f "$0")")/lib/polybar.sh" || exit 1

# polybar-fit measures the module to keep the bar from overflowing: write the output to its
# slot, but only when the width can change (title, state), not on every countdown tick
slot_file="" slot_key=""
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" && -O "$XDG_RUNTIME_DIR" ]]; then
    slot_dir="$XDG_RUNTIME_DIR/polybar-fit/$PPID"
    mkdir -p -m 700 "$XDG_RUNTIME_DIR/polybar-fit" "$slot_dir" 2>/dev/null && slot_file="$slot_dir/music"
fi
emit() {
    local key
    printf '%s\n' "$1"
    [[ -n "$slot_file" ]] || return 0
    key="${#1}:${1//[0-9]/}"
    [[ "$key" == "$slot_key" ]] && return 0
    slot_key=$key
    { printf '%s\n' "$1" > "$slot_file"; } 2>/dev/null
}

# polybar closed the pipe (restart) or stops us: leave quietly, the EXIT trap stops playerctl
trap 'exit 0' PIPE TERM INT HUP

# While nothing plays, nothing is written, so a closed pipe would go unnoticed:
# also leave when the parent (polybar) is gone.
parent=$PPID
orphaned() {
    local stat
    read -r stat < "/proc/$BASHPID/stat" || return 0
    stat=${stat##*) }
    set -- $stat
    [[ "$2" != "$parent" ]]
}

show() {
    local status=$1 pos=$2 len=$3 title icon left
    title=$(truncate "$(polybar_safe "$4")" 32)
    if [[ "$status" != "Playing" && "$status" != "Paused" ]] || [[ -z "$title" ]]; then
        emit ""
        return
    fi
    icon="󰎇"
    [[ "$status" == "Paused" ]] && icon="󰏤"
    # position and length in microseconds
    if [[ ! "$pos" =~ ^[0-9]+$ || ! "$len" =~ ^[0-9]+$ ]] || (( len == 0 )); then
        emit "%{F$DF_ACCENT}$icon %{F-}$title"
        return
    fi
    left=$(( (len - pos) / 1000000 ))
    (( left < 0 )) && left=0
    printf -v left '%02d:%02d' $(( left / 60 )) $(( left % 60 ))
    emit "%{F$DF_ACCENT}$icon %{F-}$title %{F$DF_MUTED}-$left%{F-}"
}

while true; do
    # --follow keeps running while players come and go; restart it if it ever exits
    exec {src}< <(exec playerctl --follow metadata \
        --format $'{{status}}\t{{position}}\t{{mpris:length}}\t{{title}}' 2>/dev/null)
    pid=$!
    trap 'kill "$pid" 2>/dev/null' EXIT
    while true; do
        if IFS=$'\t' read -r -t 60 status pos len title <&"$src"; then
            show "$status" "$pos" "$len" "$title"
        elif (( $? > 128 )); then
            orphaned && exit 0
        else
            break
        fi
    done
    exec {src}<&-
    kill "$pid" 2>/dev/null
    emit ""
    sleep 3
done
