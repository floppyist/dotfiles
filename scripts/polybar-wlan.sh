#!/usr/bin/env bash
# WiFi status (polybar) and network menu (rofi)
# Usage: polybar-wlan.sh [--status]
set -u

# Helpers resolved next to this script (works without ~/.local/bin in PATH)
HERE=$(dirname "$(readlink -f "$0")")
ROFI_MENU="$HERE/rofi-menu"

DF_AQUA_HI="#8ec07c" DF_YELLOW_HI="#fabd2f" DF_RED_HI="#fb4934" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

notify() { notify-send -a wifi "$@" >/dev/null 2>&1; }

# SSIDs are chosen by whoever runs the access point. Polybar parses %{...} tags in
# script output, including click actions that run commands, so break up every "%{".
# Replacement strings are quoted: since bash 5.2 an unquoted & in them means "the match".
polybar_safe() { local s=${1//[[:cntrl:]]/} pat='%{' rep='% {'; printf '%s' "${s//"$pat"/"$rep"}"; }

# Truncate to N characters (polybar's label-maxlen would also count and cut %{...} tags)
truncate() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

signal_icon() {
    local s=$1
    if   (( s >= 75 )); then printf '󰤨'
    elif (( s >= 50 )); then printf '󰤥'
    elif (( s >= 25 )); then printf '󰤢'
    else                     printf '󰤟'
    fi
}

# Polybar: one WiFi glyph whose color shows the signal (aqua >= 50 %, yellow >= 25 %, red below),
# then the SSID. Two spaces: Nerd Font icons are drawn wider than their one-cell advance.
wifi_status() {
    local line signal ssid color
    # --rescan no: the status runs on every network event and must not trigger scans
    line=$(nmcli -t -e no -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep -m1 '^yes:')
    if [[ -z "$line" ]]; then
        echo "%{F$DF_MUTED}󰖪  off%{F-}"
        return
    fi
    signal=${line#yes:}; signal=${signal%%:*}
    ssid=${line#yes:*:}
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    if   (( signal >= 50 )); then color=$DF_AQUA_HI
    elif (( signal >= 25 )); then color=$DF_YELLOW_HI
    else                          color=$DF_RED_HI
    fi
    echo "%{F$color}󰖩  %{F-}$(truncate "$(polybar_safe "$ssid")" 20)"
}

[[ "${1:-}" == "--status" ]] && { wifi_status; exit 0; }

nmcli radio wifi on >/dev/null 2>&1
nmcli device wifi rescan >/dev/null 2>&1
sleep 2

# Fields: IN-USE,SIGNAL,SECURITY,SSID (terse, ':' separated). No escaping: the SSID is the last
# field and may contain ':' or '\', it is everything after the third ':' (wifi-connect gets it
# exactly as NetworkManager names it)
mapfile -t ROWS < <(
    nmcli -t -e no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null |
        awk -F: '$4 != ""' | sort -t: -k2,2nr
)

# Deduplicate by SSID (strongest first) and build parallel arrays
declare -A SEEN
LABELS=(); SSIDS=()
for row in "${ROWS[@]}"; do
    IFS=: read -r inuse signal security _ <<< "$row"
    ssid=${row#*:*:*:}
    [[ -n "${SEEN[$ssid]:-}" ]] && continue
    SEEN[$ssid]=1
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    [[ "$security" == "--" ]] && security=""
    mark="○"; [[ "$inuse" == "*" ]] && mark="●"
    lock=" "; [[ -n "$security" ]] && lock="󰌾"
    LABELS+=("$(printf '%s  %s %3s%%  %s  %s' "$mark" "$(signal_icon "$signal")" "$signal" "$lock" "${ssid//[[:cntrl:]]/}")")
    SSIDS+=("$ssid")
done

if (( ${#SSIDS[@]} == 0 )); then
    notify -u critical "No networks found" "Is the WiFi adapter enabled?"
    exit 1
fi

IDX=$(printf '%s\n' "${LABELS[@]}" | "$ROFI_MENU" "wifi" "● connected  ·  󰌾 secured") || exit 0

# Connecting (saved profile, password prompt, new profile) goes through libnm in wifi-connect:
# the password never appears on a command line, and polkit asks in its own dialog.
exec "$HERE/wifi-connect" "${SSIDS[$IDX]}"
