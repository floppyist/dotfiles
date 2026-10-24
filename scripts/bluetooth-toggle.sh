#!/usr/bin/env bash
# Toggle Bluetooth (rfkill + controller power)
set -u

notify() { notify-send "Bluetooth" "$1"; }

is_on() {
    ! rfkill -n -o SOFT list bluetooth | grep -q '^blocked' &&
        bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'
}

if is_on; then
    bluetoothctl power off >/dev/null 2>&1
    rfkill block bluetooth
    notify "off"
    exit 0
fi

if rfkill -n -o HARD list bluetooth | grep -q '^blocked'; then
    notify-send -u critical "Bluetooth" "Hard-blocked (hardware switch)"
    exit 1
fi

rfkill unblock bluetooth
# The controller needs a moment to reappear after unblocking
for _ in {1..10}; do
    if bluetoothctl power on >/dev/null 2>&1; then
        notify "on"
        exit 0
    fi
    sleep 0.3
done

notify-send -u critical "Bluetooth" "Failed to power on"
exit 1
