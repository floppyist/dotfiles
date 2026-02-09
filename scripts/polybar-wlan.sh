#!/bin/bash
# WiFi Manager - Ultra Minimal and Robust

wifi_status() {
    local active=$(nmcli -t -f NAME,TYPE connection show --active | grep ":802-11-wireless" | cut -d':' -f1 | head -1)
    if [[ -z "$active" ]]; then
        echo "%{F#a89984}WiFi%{F-} off"
    else
        echo "%{F#458588}WiFi%{F-} $active"
    fi
}

scan_networks() {
    nmcli radio wifi on >/dev/null 2>&1
    notify-send "WiFi" "Scanning..." >/dev/null 2>&1
    
    nmcli device wifi rescan >/dev/null 2>&1
    sleep 3
    
    nmcli -t -f SSID device wifi list | grep -v '^--' | grep -v '^$' | sort -u
}

connect_network() {
    local ssid="$1"
    
    # Try direct connect first (creates/uses profile automatically)
    notify-send "WiFi" "Connecting to $ssid..." >/dev/null 2>&1
    
    # Try with saved password first
    if timeout 15 nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        sleep 2
        notify-send "WiFi" "Connected to $ssid" >/dev/null 2>&1
        return 0
    fi
    
    # Ask for password
    local password=$(rofi -dmenu -password -p "Password for $ssid" \
                      -theme-str 'window { width: 25%; }' \
                      -theme ~/.config/rofi/config.rasi 2>/dev/null)
    
    [[ -z "$password" ]] && return 1
    
    # Connect with password
    notify-send "WiFi" "Connecting to $ssid..." >/dev/null 2>&1
    
    if timeout 15 nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1; then
        sleep 2
        notify-send "WiFi" "Connected to $ssid" >/dev/null 2>&1
        return 0
    else
        notify-send "WiFi Error" "Failed to connect to $ssid" -u critical >/dev/null 2>&1
        return 1
    fi
}

if [[ "${1:-}" == "--status" ]]; then
    wifi_status
    exit 0
fi

networks=$(scan_networks)
[[ -z "$networks" ]] && exit 1

chosen=$(echo -e "$networks" | rofi -dmenu -i -p "WiFi" \
    -mesg "NETWORK MANAGER" \
    -theme-str 'window { width: 25%; }' \
    -theme-str 'listview { lines: 10; }' \
    -theme ~/.config/rofi/config.rasi)

[[ -z "$chosen" ]] && exit 0
chosen=$(echo "$chosen" | xargs)
connect_network "$chosen"