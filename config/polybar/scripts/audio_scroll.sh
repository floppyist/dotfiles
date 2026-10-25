#!/usr/bin/env bash
# Now-playing text for the polybar music module: "Title  -mm:ss"
#
# Track titles come from websites (browser MPRIS) and media files, so they are untrusted:
# - Polybar parses %{...} tags in script output, including click actions that run
#   commands, so every "%{" is broken up.
# - Numbers are validated before bash arithmetic (it evaluates expressions recursively).
set -u

polybar_safe() { local s=${1//[[:cntrl:]]/} pat='%{' rep='% {'; printf '%s' "${s//"$pat"/"$rep"}"; }

# Truncate to N characters (polybar's label-maxlen would also count and cut %{...} tags)
truncate() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

status=$(playerctl status 2>/dev/null) || { echo ""; exit 0; }
[[ "$status" == "Playing" || "$status" == "Paused" ]] || { echo ""; exit 0; }

title=$(truncate "$(polybar_safe "$(playerctl metadata --format '{{ title }}' 2>/dev/null)")" 32)
[[ -n "$title" ]] || { echo ""; exit 0; }

icon="󰎇"
[[ "$status" == "Paused" ]] && icon="󰏤"

pos=$(playerctl position 2>/dev/null); pos=${pos%%.*}
len=$(playerctl metadata mpris:length 2>/dev/null)

if [[ ! "$pos" =~ ^[0-9]+$ || ! "$len" =~ ^[0-9]+$ || "$len" == 0 ]]; then
    printf '%%{F#cc241d}%s %%{F-}%s\n' "$icon" "$title"
    exit 0
fi

left=$(( len / 1000000 - pos ))
(( left < 0 )) && left=0
printf '%%{F#cc241d}%s %%{F-}%s %%{F#7c6f64}-%02d:%02d%%{F-}\n' "$icon" "$title" $(( left / 60 )) $(( left % 60 ))
