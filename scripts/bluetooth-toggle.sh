#!/usr/bin/env bash
# Toggle Bluetooth (Super+b): controller power on/off.
# Off only powers the controller down; it does not rfkill-block the adapter,
# because the Intel AX200 (btusb) can fail to power on again after rfkill cycles.
set -u

notify() { notify-send -a bluetooth "$@" >/dev/null 2>&1; }

is_on() {
    ! rfkill -n -o SOFT list bluetooth | grep -q '^blocked' &&
        bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'
}

if is_on; then
    bluetoothctl power off >/dev/null 2>&1
    notify "Bluetooth off" "Controller powered down"
    exit 0
fi

if rfkill -n -o HARD list bluetooth | grep -q '^blocked'; then
    notify -u critical "Bluetooth blocked" "Hardware switch is off"
    exit 1
fi

rfkill unblock bluetooth
# The controller needs a moment to reappear after unblocking
for _ in {1..10}; do
    if bluetoothctl power on >/dev/null 2>&1; then
        notify "Bluetooth on" "Controller ready"
        exit 0
    fi
    sleep 0.3
done

notify -u critical "Bluetooth failed to power on" "Reload the driver: sudo modprobe -r btusb && sudo modprobe btusb"
exit 1
