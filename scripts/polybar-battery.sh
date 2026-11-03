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

# Every system battery (some laptops have two: one capsule for both). type Battery and scope
# not Device: a wireless mouse or headset reports a battery here too.
shopt -s nullglob
now=0 full=0 caps=0 n=0 state=""
for b in /sys/class/power_supply/*; do
    t="" scope="" c="" s=""
    read -r t 2>/dev/null < "$b/type"; [[ ${t-} == Battery ]] || continue
    read -r scope 2>/dev/null < "$b/scope" && [[ $scope == Device ]] && continue
    read -r c 2>/dev/null < "$b/capacity"; [[ ${c-} =~ ^[0-9]+$ ]] || continue
    read -r s 2>/dev/null < "$b/status" || s=Unknown
    (( n++, caps += c ))
    # energy (µWh) or charge (µAh): weighs the batteries by their size
    for kind in energy charge; do
        if read -r e 2>/dev/null < "$b/${kind}_now" && read -r f 2>/dev/null < "$b/${kind}_full" &&
           [[ $e =~ ^[0-9]+$ && $f =~ ^[0-9]+$ ]] && (( f > 0 )); then
            (( now += e, full += f ))
            break
        fi
    done
    # one charging battery makes the whole charging; Discharging wins over Full/Not charging
    case $s in
        Charging) state=Charging ;;
        Discharging) [[ $state == Charging ]] || state=Discharging ;;
        *) [[ -z $state ]] && state=$s ;;
    esac
done
(( n )) || { echo ""; exit 0; }
if (( n > 1 && full > 0 )); then cap=$(( (now * 100 + full / 2) / full )); else cap=$(( caps / n )); fi
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
