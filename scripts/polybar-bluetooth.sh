#!/bin/bash
# Simple Bluetooth Manager - Static List

bt_status() {
    local connected=$(bluetoothctl info 2>/dev/null | grep "Name:" | cut -d' ' -f2- | head -1)
    if [[ -z "$connected" ]]; then
        echo "%{F#a89984}%{F-} off"
    else
        echo "%{F#458588}%{F-} $connected"
    fi
}

# List known paired devices - multiple fallback methods
scan_devices() {
    bluetoothctl power on >/dev/null 2>&1
    
    # Method 1: Try paired-devices first
    local devices=$(bluetoothctl paired-devices 2>/dev/null | grep "Device ")
    
    # Method 2: Fallback to 'devices' command if paired-devices is empty
    if [[ -z "$devices" ]]; then
        devices=$(bluetoothctl devices 2>/dev/null | grep "Device ")
    fi
    
    # Method 3: Last resort - try to list with bluetoothctl list and scan briefly
    if [[ -z "$devices" ]]; then
        bluetoothctl scan on >/dev/null 2>&1 &
        local scan_pid=$!
        sleep 3  # Quick 3-second scan
        kill $scan_pid >/dev/null 2>&1
        bluetoothctl scan off >/dev/null 2>&1
        sleep 1
        devices=$(bluetoothctl devices 2>/dev/null | grep "Device ")
    fi
    
    # Process found devices
    if [[ -n "$devices" ]]; then
        echo "$devices" | while read -r line; do
            local mac=$(echo "$line" | cut -d' ' -f2)
            local name=$(echo "$line" | cut -d' ' -f3-)
            local connected="disconnected"
            
            if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
                connected="connected"
            fi
            
            echo "$name ($mac) [$connected]"
        done | sort
    fi
}

# Simple connect
connect_device() {
    local device_info="$1"
    local name=$(echo "$device_info" | sed 's/ *(.*) \[.*\]//')
    local mac=$(echo "$device_info" | sed 's/.*(\([^)]*\)).*/\1/')
    local status=$(echo "$device_info" | sed 's/.*\[\([^]]*\)\].*/\1/')
    
    [[ -z "$mac" ]] && return 1
    
    # If already connected, do nothing
    if [[ "$status" == "connected" ]]; then
        notify-send "Bluetooth" "$name is already connected" >/dev/null 2>&1
        return 0
    fi
    
    notify-send "Bluetooth" "Connecting to $name..." >/dev/null 2>&1
    
    bluetoothctl connect "$mac" >/dev/null 2>&1
    
    sleep 3
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
        notify-send "Bluetooth" "Connected to $name" >/dev/null 2>&1
    else
        notify-send "Bluetooth Error" "Failed to connect to $name" -u critical >/dev/null 2>&1
    fi
}

# Main
if [[ "${1:-}" == "--status" ]]; then
    bt_status
    exit 0
fi

if [[ "${1:-}" == "--debug" ]]; then
    echo "=== DEBUG INFO ==="
    echo "Bluetooth power status:"
    bluetoothctl show 2>/dev/null | grep -E "(Power|Powered)"
    echo ""
    echo "Paired devices:"
    bluetoothctl paired-devices 2>/dev/null || echo "No paired devices or command failed"
    echo ""
    echo "All devices:"
    bluetoothctl devices 2>/dev/null || echo "No devices or command failed"
    echo ""
    echo "=== SCAN RESULT ==="
    scan_devices
    exit 0
fi

# Scan once
devices=$(scan_devices)

if [[ -z "$devices" ]]; then
    notify-send "Bluetooth Error" "No devices found" -u critical >/dev/null 2>&1
    echo "Debug with: $0 --debug"
    exit 1
fi

# Show menu once
chosen=$(echo -e "$devices" | rofi -dmenu -i -p "" \
    -mesg "BLUETOOTH MANAGER" \
    -theme-str 'window { width: 30%; }' \
    -theme-str 'listview { lines: 10; }' \
    -theme ~/.config/rofi/config.rasi)

[[ -z "$chosen" ]] && exit 0

connect_device "$chosen"