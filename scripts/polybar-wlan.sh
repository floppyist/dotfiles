#!/usr/bin/env bash
# WiFi status (polybar) and network menu (rofi)
# Usage: polybar-wlan.sh [--status]
set -u

# Shared menu helper, resolved next to this script (works without ~/.local/bin in PATH)
ROFI_MENU="$(dirname "$(readlink -f "$0")")/rofi-menu"

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

# rofi -mesg is pango markup
markup_safe() { local s=${1//'&'/'&amp;'}; s=${s//'<'/'&lt;'}; printf '%s' "${s//'>'/'&gt;'}"; }

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
    line=$(nmcli -t -f ACTIVE,SIGNAL,SSID device wifi list --rescan no 2>/dev/null | grep -m1 '^yes:')
    if [[ -z "$line" ]]; then
        echo "%{F$DF_MUTED}󰖪  off%{F-}"
        return
    fi
    signal=${line#yes:}; signal=${signal%%:*}
    ssid=${line#yes:*:}; ssid=${ssid//\\:/:}
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    if   (( signal >= 50 )); then color=$DF_AQUA_HI
    elif (( signal >= 25 )); then color=$DF_YELLOW_HI
    else                          color=$DF_RED_HI
    fi
    echo "%{F$color}󰖩  %{F-}$(truncate "$(polybar_safe "$ssid")" 20)"
}

[[ "${1:-}" == "--status" ]] && { wifi_status; exit 0; }

# Known connection profile for this SSID?
has_profile() {
    nmcli -t -f NAME connection show | grep -qxF -- "$1"
}

ask_password() {
    rofi -dmenu -password -p "wifi" -theme "$HOME/.config/rofi/config.rasi" \
        -mesg "Password for $(markup_safe "$1")" \
        -theme-str 'listview { enabled: false; }' \
        -theme-str 'entry { placeholder: "password"; }' < /dev/null 2>/dev/null
}

connect_network() {
    local ssid=$1 security=$2 password

    notify "Connecting" "$ssid"

    # Open network or known profile: no password needed
    if [[ -z "$security" ]] || has_profile "$ssid"; then
        if timeout 20 nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify "Connected" "$ssid"
            return 0
        fi
        # Known profile may have a stale password: fall through to prompt
        [[ -z "$security" ]] && { notify -u critical "Connection failed" "$ssid"; return 1; }
    fi

    password=$(ask_password "$ssid")
    [[ -z "$password" ]] && return 1

    # Remove the stale profile so the new password is used
    has_profile "$ssid" && nmcli connection delete id "$ssid" >/dev/null 2>&1

    notify "Authenticating" "$ssid"
    # --ask reads the password from stdin, so it is not visible in `ps`
    if printf '%s\n' "$password" | timeout 30 nmcli --ask device wifi connect "$ssid" >/dev/null 2>&1; then
        notify "Connected" "$ssid"
    else
        notify -u critical "Connection failed" "$ssid (wrong password?)"
        return 1
    fi
}

nmcli radio wifi on >/dev/null 2>&1
nmcli device wifi rescan >/dev/null 2>&1
sleep 2

# Fields: IN-USE,SIGNAL,SECURITY,SSID (terse, ':' separated, SSID last)
mapfile -t ROWS < <(
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan no 2>/dev/null |
        awk -F: '$4 != ""' | sort -t: -k2,2nr
)

# Deduplicate by SSID (strongest first) and build parallel arrays
declare -A SEEN
LABELS=(); SSIDS=(); SECS=()
for row in "${ROWS[@]}"; do
    IFS=: read -r inuse signal security _ <<< "$row"
    # SSIDs containing ':' are escaped as '\:' and were split; re-join the rest
    ssid=${row#*:*:*:}
    ssid=${ssid//\\:/:}
    [[ -n "${SEEN[$ssid]:-}" ]] && continue
    SEEN[$ssid]=1
    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    [[ "$security" == "--" ]] && security=""
    mark="○"; [[ "$inuse" == "*" ]] && mark="●"
    lock=" "; [[ -n "$security" ]] && lock="󰌾"
    LABELS+=("$(printf '%s  %s %3s%%  %s  %s' "$mark" "$(signal_icon "$signal")" "$signal" "$lock" "${ssid//[[:cntrl:]]/}")")
    SSIDS+=("$ssid")
    SECS+=("$security")
done

if (( ${#SSIDS[@]} == 0 )); then
    notify -u critical "No networks found" "Is the WiFi adapter enabled?"
    exit 1
fi

IDX=$(printf '%s\n' "${LABELS[@]}" | "$ROFI_MENU" "wifi" "● connected  ·  󰌾 secured") || exit 0

connect_network "${SSIDS[$IDX]}" "${SECS[$IDX]}"
