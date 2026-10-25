#!/usr/bin/env bash
# Bluetooth status (polybar) and device menu (rofi)
# Usage: polybar-bluetooth.sh [--status|--debug]
set -u

# Shared menu helper, resolved next to this script (works without ~/.local/bin in PATH)
ROFI_MENU="$(dirname "$(readlink -f "$0")")/rofi-menu"

ICON_ON="󰂱"   # md-bluetooth_connect
ICON_IDLE="󰂯" # md-bluetooth
ICON_OFF="󰂲"  # md-bluetooth_off
C_ON="#83a598"
C_OFF="#7c6f64"

notify() { notify-send -a bluetooth "$@" >/dev/null 2>&1; }

# Device names are chosen by the remote device. Polybar parses %{...} tags in script
# output (including click actions that run commands), so break up every "%{".
# Replacement strings are quoted: since bash 5.2 an unquoted & in them means "the match".
polybar_safe() { local s=${1//[[:cntrl:]]/} pat='%{' rep='% {'; printf '%s' "${s//"$pat"/"$rep"}"; }

# Truncate to N characters (polybar's label-maxlen would also count and cut %{...} tags)
truncate() { local s=$1 n=$2; (( ${#s} > n )) && s="${s:0:n-1}…"; printf '%s' "$s"; }

powered() { bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; }

# "MAC Name" lines of connected devices
connected_devices() {
    bluetoothctl devices Connected 2>/dev/null | sed -n 's/^Device //p'
}

bt_status() {
    if ! powered; then
        echo "%{F$C_OFF}$ICON_OFF %{F-}"
        return
    fi
    local list count first
    list=$(connected_devices)
    if [[ -z "$list" ]]; then
        echo "%{F$C_OFF}$ICON_IDLE %{F-}"
        return
    fi
    count=$(wc -l <<< "$list")
    first=$(truncate "$(polybar_safe "$(head -n1 <<< "$list" | cut -d' ' -f2-)")" 20)
    if (( count > 1 )); then
        echo "%{F$C_ON}$ICON_ON %{F-}$first +$((count - 1))"
    else
        echo "%{F$C_ON}$ICON_ON %{F-}$first"
    fi
}

# Paired devices ("MAC Name"); falls back to a short scan if nothing is known
list_devices() {
    local devices
    devices=$(bluetoothctl devices Paired 2>/dev/null | sed -n 's/^Device //p')
    if [[ -z "$devices" ]]; then
        notify "Scanning" "No paired devices, scanning for 5 s…"
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
        echo "=== Controller ==="; bluetoothctl show 2>&1 | grep -E 'Powered|Discoverable|PowerState'
        echo "=== Paired ===";     bluetoothctl devices Paired 2>&1
        echo "=== Connected ===";  bluetoothctl devices Connected 2>&1
        exit 0
        ;;
esac

if ! powered; then
    bluetoothctl power on >/dev/null 2>&1
    sleep 1
    powered || { notify -u critical "Bluetooth is off" "Turn it on with Super+b"; exit 1; }
fi

mapfile -t DEVICES < <(list_devices)
if (( ${#DEVICES[@]} == 0 )); then
    notify -u critical "No devices found" "See: polybar-bluetooth.sh --debug"
    exit 1
fi

CONNECTED=$(connected_devices | cut -d' ' -f1)

LABELS=()
for line in "${DEVICES[@]}"; do
    mac=${line%% *}
    name=${line#* }
    name=${name//[[:cntrl:]]/}
    if grep -qxF "$mac" <<< "$CONNECTED"; then
        LABELS+=("●  $name")
    else
        LABELS+=("○  $name")
    fi
done

IDX=$(printf '%s\n' "${LABELS[@]}" | "$ROFI_MENU" "bluetooth" "● connected  ·  select to toggle") || exit 0

line=${DEVICES[$IDX]}
mac=${line%% *}
name=${line#* }

if grep -qxF "$mac" <<< "$CONNECTED"; then
    if bluetoothctl disconnect "$mac" >/dev/null 2>&1; then
        notify "Disconnected" "$name"
    else
        notify -u critical "Disconnect failed" "$name"
    fi
    exit 0
fi

notify "Connecting" "$name"
bluetoothctl connect "$mac" >/dev/null 2>&1
if wait_connected "$mac"; then
    notify "Connected" "$name"
else
    notify -u critical "Connection failed" "$name"
    exit 1
fi
