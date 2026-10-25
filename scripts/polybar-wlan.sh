#!/usr/bin/env bash
# WiFi status (polybar) and network menu (rofi)
# Usage: polybar-wlan.sh [--status]
set -u

THEME="$HOME/.config/rofi/config.rasi"

notify() { notify-send -a "WiFi" "$@" >/dev/null 2>&1; }

wifi_status() {
    local active
    active=$(nmcli -t -f ACTIVE,SSID device wifi list 2>/dev/null | sed -n 's/^yes://p' | head -n1)
    active=${active//\\:/:}
    if [[ -z "$active" ]]; then
        echo "%{F#a89984}WiFi%{F-} off"
    else
        echo "%{F#458588}WiFi%{F-} $active"
    fi
}

[[ "${1:-}" == "--status" ]] && { wifi_status; exit 0; }

rofi_menu() {
    rofi -dmenu -i "$@" -theme "$THEME"
}

# Known connection profile for this SSID?
has_profile() {
    nmcli -t -f NAME connection show | grep -qxF -- "$1"
}

connect_network() {
    local ssid=$1 security=$2 password

    notify "WiFi" "Connecting to $ssid..."

    # Open network or known profile: no password needed
    if [[ -z "$security" ]] || has_profile "$ssid"; then
        if timeout 20 nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            notify "WiFi" "Connected to $ssid"
            return 0
        fi
        # Known profile may have a stale password: fall through to prompt
        [[ -z "$security" ]] && { notify -u critical "WiFi Error" "Failed to connect to $ssid"; return 1; }
    fi

    password=$(rofi_menu -password -p "Password for $ssid" \
        -theme-str 'window { width: 25%; }' \
        -theme-str "entry { placeholder: \"Password...\"; }" 2>/dev/null)
    [[ -z "$password" ]] && return 1

    # Remove the stale profile so the new password is used
    has_profile "$ssid" && nmcli connection delete id "$ssid" >/dev/null 2>&1

    notify "WiFi" "Authenticating..."
    # --ask reads the password from stdin, so it is not visible in `ps`
    if printf '%s\n' "$password" | timeout 30 nmcli --ask device wifi connect "$ssid" >/dev/null 2>&1; then
        notify "WiFi" "Connected to $ssid"
    else
        notify -u critical "WiFi Error" "Failed to connect to $ssid"
        return 1
    fi
}

nmcli radio wifi on >/dev/null 2>&1

# Show cached list immediately; refresh in background-friendly way
nmcli device wifi rescan >/dev/null 2>&1
sleep 2

# Fields: IN-USE,SIGNAL,SECURITY,SSID (terse, ':' separated, SSID last)
mapfile -t ROWS < <(
    nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list 2>/dev/null |
        awk -F: '$4 != "" ' | sort -t: -k2,2nr
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
    mark=" "; [[ "$inuse" == "*" ]] && mark="*"
    lock=""; [[ -n "$security" && "$security" != "--" ]] && lock="🔒"
    [[ "$security" == "--" ]] && security=""
    LABELS+=("$(printf '%s %3s%%  %-2s %s' "$mark" "$signal" "$lock" "$ssid")")
    SSIDS+=("$ssid")
    SECS+=("$security")
done

if (( ${#SSIDS[@]} == 0 )); then
    notify -u critical "WiFi" "No networks found"
    exit 1
fi

IDX=$(printf '%s\n' "${LABELS[@]}" | rofi_menu -p "WiFi" -format i \
    -mesg "NETWORK MANAGER" \
    -theme-str 'window { width: 30%; }' \
    -theme-str 'listview { lines: 10; }')

[[ -z "$IDX" ]] && exit 0

connect_network "${SSIDS[$IDX]}" "${SECS[$IDX]}"
