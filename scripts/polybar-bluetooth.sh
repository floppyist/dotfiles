#!/usr/bin/env bash
# Bluetooth status (polybar) and device menu (rofi)
# Usage: polybar-bluetooth.sh [--status|--debug]
set -u

ICON=$'\uf293'
C_OFF="#a89984"
C_ON="#458588"
THEME="$HOME/.config/rofi/config.rasi"

notify() { notify-send -a "Bluetooth" "$@" >/dev/null 2>&1; }

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

# "MAC Name" lines of connected devices
connected_devices() {
    bluetoothctl devices Connected 2>/dev/null | sed -n 's/^Device //p'
}

bt_status() {
    if ! powered; then
        echo "%{F$C_OFF}$ICON%{F-}"
        return
    fi
    local list count first
    list=$(connected_devices)
    if [[ -z "$list" ]]; then
        echo "%{F$C_OFF}$ICON%{F-}"
        return
    fi
    count=$(wc -l <<< "$list")
    first=$(head -n1 <<< "$list" | cut -d' ' -f2-)
    if (( count > 1 )); then
        echo "%{F$C_ON}$ICON%{F-} $first +$((count - 1))"
    else
        echo "%{F$C_ON}$ICON%{F-} $first"
    fi
}

# Paired devices ("MAC Name"); falls back to a short scan if nothing is known
list_devices() {
    local devices
    devices=$(bluetoothctl devices Paired 2>/dev/null | sed -n 's/^Device //p')
    if [[ -z "$devices" ]]; then
        notify "Bluetooth" "No paired devices, scanning for 5s..."
        bluetoothctl --timeout 5 scan on >/dev/null 2>&1
        devices=$(bluetoothctl devices 2>/dev/null | sed -n 's/^Device //p')
    fi
    printf '%s\n' "$devices" | sed '/^$/d'
}

wait_connected() {
    local mac=$1 _
    for _ in {1..10}; do
        bluetoothctl info "$mac" 2>/dev/null | grep -q 'Connected: yes' && return 0
        sleep 0.5
    done
    return 1
}

case "${1:-}" in
    --status)
        bt_status
        exit 0
        ;;
    --debug)
        echo "=== Controller ==="; bluetoothctl show 2>&1 | grep -E 'Powered|Discoverable'
        echo "=== Paired ===";     bluetoothctl devices Paired 2>&1
        echo "=== Connected ===";  bluetoothctl devices Connected 2>&1
        exit 0
        ;;
esac

if ! powered; then
    bluetoothctl power on >/dev/null 2>&1
    sleep 1
    powered || { notify -u critical "Bluetooth Error" "Bluetooth is off (try bluetooth-toggle.sh)"; exit 1; }
fi

mapfile -t DEVICES < <(list_devices)
if (( ${#DEVICES[@]} == 0 )); then
    notify -u critical "Bluetooth Error" "No devices found (see: $0 --debug)"
    exit 1
fi

CONNECTED=$(connected_devices | cut -d' ' -f1)

LABELS=()
for line in "${DEVICES[@]}"; do
    mac=${line%% *}
    name=${line#* }
    if grep -qx "$mac" <<< "$CONNECTED"; then
        LABELS+=("● $name")
    else
        LABELS+=("○ $name")
    fi
done

IDX=$(printf '%s\n' "${LABELS[@]}" | rofi -dmenu -i -p "" -format i \
    -theme "$THEME" \
    -mesg "BLUETOOTH  (● connected: select to disconnect)" \
    -theme-str 'window { width: 30%; }' \
    -theme-str 'listview { lines: 10; }')

[[ -z "$IDX" ]] && exit 0

line=${DEVICES[$IDX]}
mac=${line%% *}
name=${line#* }

if grep -qx "$mac" <<< "$CONNECTED"; then
    if bluetoothctl disconnect "$mac" >/dev/null 2>&1; then
        notify "Bluetooth" "Disconnected from $name"
    else
        notify -u critical "Bluetooth Error" "Failed to disconnect from $name"
    fi
    exit 0
fi

notify "Bluetooth" "Connecting to $name..."
bluetoothctl connect "$mac" >/dev/null 2>&1
if wait_connected "$mac"; then
    notify "Bluetooth" "Connected to $name"
else
    notify -u critical "Bluetooth Error" "Failed to connect to $name"
    exit 1
fi
