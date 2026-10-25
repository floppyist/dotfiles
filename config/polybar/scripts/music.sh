#!/usr/bin/env bash
# Now playing for the polybar music module (tail = true): "<icon> Title  -mm:ss"
#
# Event-driven: `playerctl --follow` prints a line when the status, the track or the
# position changes. While playing that is once per second (the countdown), while paused
# or stopped nothing at all, so the module costs nothing when no music runs.
#
# Track titles come from websites (browser MPRIS) and media files, so they are untrusted:
# - Polybar parses %{...} tags in script output, including click actions that run
#   commands, so every "%{" is broken up.
# - Numbers are validated before bash arithmetic (it evaluates expressions recursively).
set -u

DF_ACCENT="#cc241d" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

polybar_safe() { local s=${1//[[:cntrl:]]/} pat='%{' rep='% {'; printf '%s' "${s//"$pat"/"$rep"}"; }

# Truncate to N characters (polybar's label-maxlen would also count and cut %{...} tags)
truncate() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

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
        echo ""
        return
    fi
    icon="󰎇"
    [[ "$status" == "Paused" ]] && icon="󰏤"
    # position and length in microseconds
    if [[ ! "$pos" =~ ^[0-9]+$ || ! "$len" =~ ^[0-9]+$ ]] || (( len == 0 )); then
        printf '%%{F%s}%s %%{F-}%s\n' "$DF_ACCENT" "$icon" "$title"
        return
    fi
    left=$(( (len - pos) / 1000000 ))
    (( left < 0 )) && left=0
    printf '%%{F%s}%s %%{F-}%s %%{F%s}-%02d:%02d%%{F-}\n' \
        "$DF_ACCENT" "$icon" "$title" "$DF_MUTED" $(( left / 60 )) $(( left % 60 ))
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
    echo ""
    sleep 3
done
