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

# Several players at once (an idle mpv next to Firefox playing YouTube): playerctl reports each of
# them (--all-players), and showing every line made the capsule jump between them and go blank.
# State per player instead (by instance: two Firefox windows are two players); shown is the player
# that started playing last, else the paused one. A gap of a moment (track change, ad) does not
# blank the capsule.
# Fields are separated by \x1f, not tabs: read collapses repeated tab separators (tab is IFS
# whitespace), so a player without position or length (Firefox) shifted its title out of place.
SEP=$'\x1f'
declare -A p_status p_pos p_len p_title p_seq
seq=0 best_player=""

# the player to show -> best_player (empty: none)
choose() {
    local n rank r bs=-1
    best_player=""
    for n in "${!p_status[@]}"; do
        case ${p_status[$n]} in Playing) rank=2 ;; Paused) rank=1 ;; *) continue ;; esac
        [[ -n ${p_title[$n]} ]] || continue
        r=$(( rank * 1000000 + ${p_seq[$n]:-0} ))
        (( r > bs )) && { bs=$r; best_player=$n; }
    done
}

forget() { unset "p_status[$1]" "p_pos[$1]" "p_len[$1]" "p_title[$1]" "p_seq[$1]"; }

# forget players that are gone (a closed player sends no line of its own)
prune() {
    local n alive
    alive=" $(playerctl -l 2>/dev/null | tr '\n' ' ')"
    for n in "${!p_status[@]}"; do
        [[ $alive == *" $n "* ]] || forget "$n"
    done
}

update() {
    local name=$1 status=$2
    if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
        prune          # an empty line: a player went away
        return 0
    fi
    if [[ -z $status ]]; then
        forget "$name"
        return 0
    fi
    # the order of starting decides between two playing players, not who reported last
    [[ $status != "${p_status[$name]-}" ]] && p_seq[$name]=$(( ++seq ))
    p_status[$name]=$status p_pos[$name]=$3 p_len[$name]=$4 p_title[$name]=$5
}

refresh() {
    choose
    if [[ -n $best_player ]]; then
        blank_wait=0
        show "${p_status[$best_player]}" "${p_pos[$best_player]}" "${p_len[$best_player]}" "${p_title[$best_player]}"
    else
        blank_wait=1       # blank only if nothing comes back within 2 s
    fi
}

blank_wait=0
while true; do
    # --follow keeps running while players come and go; restart it if it ever exits
    exec {src}< <(exec playerctl --all-players --follow metadata \
        --format "{{playerInstance}}$SEP{{status}}$SEP{{position}}$SEP{{mpris:length}}$SEP{{title}}" 2>/dev/null)
    pid=$!
    trap 'kill "$pid" 2>/dev/null' EXIT
    while true; do
        if IFS=$SEP read -r -t "$(( blank_wait ? 2 : 60 ))" name status pos len title <&"$src"; then
            update "$name" "$status" "$pos" "$len" "$title"
            refresh
        elif (( $? > 128 )); then
            orphaned && exit 0
            if (( blank_wait )); then
                blank_wait=0
                emit ""
            else
                prune
                refresh
            fi
        else
            break
        fi
    done
    exec {src}<&-
    kill "$pid" 2>/dev/null
    p_status=() p_pos=() p_len=() p_title=() p_seq=()
    blank_wait=0
    emit ""
    sleep 3
done
