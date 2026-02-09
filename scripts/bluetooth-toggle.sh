#!/bin/bash

if rfkill list bluetooth | grep -q "yes"; then
    rfkill unblock bluetooth
    bluetoothctl power on
    notify-send "Bluetooth" "on" -i bluetooth-on
else
    bluetoothctl power off
    rfkill block bluetooth
    notify-send "Bluetooth" "off" -i bluetooth-off
fi
