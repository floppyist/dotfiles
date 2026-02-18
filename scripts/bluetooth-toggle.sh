#!/bin/bash

if rfkill list bluetooth | grep -q "yes"; then
    rfkill unblock bluetooth
    bluetoothctl power on
    notify-send "Bluetooth" "on"
else
    bluetoothctl power off
    rfkill block bluetooth
    notify-send "Bluetooth" "off"
fi
