#!/usr/bin/env bash
# Battery for polybar: " <icon> 85% " (the module has no padding: low battery paints the
# whole capsule red). Run through polybar-watch with `udevadm monitor`, so plugging in
# the charger shows up at once and nothing polls the battery every few seconds.
# Usage: polybar-battery.sh [--status]
set -u

DF_BG="#191c1c" DF_RED="#cc241d" DF_GREEN_HI="#b8bb26" DF_YELLOW_HI="#fabd2f" DF_SUBTLE="#a89984"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

LOW=15
FULL=99

shopt -s nullglob
BATS=(/sys/class/power_supply/BAT*)
(( ${#BATS[@]} )) || { echo ""; exit 0; }

read -r cap < "${BATS[0]}/capacity" 2>/dev/null || cap=""
read -r state < "${BATS[0]}/status" 2>/dev/null || state="Unknown"
[[ "$cap" =~ ^[0-9]+$ ]] || { echo ""; exit 0; }
(( cap > 100 )) && cap=100

case "$state" in
    Full)
        echo " %{F$DF_GREEN_HI}󰁹 %{F-}full "
        ;;
    Charging)
        echo " %{F$DF_GREEN_HI}󰂄 %{F-}$cap% "
        ;;
    "Not charging")
        # on AC, held below 100 % by a charge threshold
        if (( cap >= FULL )); then echo " %{F$DF_GREEN_HI}󰁹 %{F-}full "
        else echo " %{F$DF_SUBTLE}󰚥  %{F-}$cap% "; fi
        ;;
    *)
        if (( cap <= LOW )); then
            echo "%{B$DF_RED}%{F$DF_BG} 󰂃 $cap% %{F-}%{B-}"
        else
            icons=(󰁺 󰁼 󰁾 󰂀 󰂂 󰁹)
            i=$(( cap * ${#icons[@]} / 101 ))
            echo " %{F$DF_YELLOW_HI}${icons[$i]} %{F-}$cap% "
        fi
        ;;
esac
