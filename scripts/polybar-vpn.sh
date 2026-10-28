#!/usr/bin/env bash
# VPN status for polybar (run through polybar-watch with `nmcli monitor`).
#   connected   green shield + profile name (+N when several tunnels are up)
#   connecting  yellow shield + name
#   off         grey shield (VPN profiles exist)
#   no profiles nothing (the module disappears)
# Click: `vpn` (menu), right click: `vpn toggle`.
# Usage: polybar-vpn.sh [--status]
set -u

ICON_ON="󰦝"    # md-shield_lock
ICON_OFF="󰦞"   # md-shield_off
DF_GREEN_HI="#b8bb26" DF_YELLOW_HI="#fabd2f" DF_MUTED="#7c6f64"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

# polybar_safe, truncate (profile names come from imported files, so from whoever wrote them)
# shellcheck source=lib/polybar.sh
. "$(dirname "$(readlink -f "$0")")/lib/polybar.sh" || exit 1

# nmcli -t escapes ':' and '\' in values
unescape() { local s=${1//\\:/:}; printf '%s' "${s//\\\\/\\}"; }

vpn_status() {
    local line type state name up="" wait="" count=0
    while IFS= read -r line; do
        type=${line%%:*}; line=${line#*:}
        state=${line%%:*}; name=${line#*:}
        [[ "$type" == vpn || "$type" == wireguard ]] || continue
        case "$state" in
            activated)  (( count++ )); [[ -z "$up" ]] && up=$(unescape "$name") ;;
            activating) [[ -z "$wait" ]] && wait=$(unescape "$name") ;;
        esac
    done < <(nmcli -t -f TYPE,STATE,NAME connection show --active 2>/dev/null)

    if [[ -n "$up" ]]; then
        local more=""
        (( count > 1 )) && more=" +$((count - 1))"
        echo "%{F$DF_GREEN_HI}$ICON_ON  %{F-}$(truncate "$(polybar_safe "$up")" 16)$more"
    elif [[ -n "$wait" ]]; then
        echo "%{F$DF_YELLOW_HI}$ICON_ON  %{F-}$(truncate "$(polybar_safe "$wait")" 16)"
    elif nmcli -t -f TYPE connection show 2>/dev/null | grep -qxE 'vpn|wireguard'; then
        echo "%{F$DF_MUTED}$ICON_OFF %{F-}"
    else
        echo ""
    fi
}

vpn_status
