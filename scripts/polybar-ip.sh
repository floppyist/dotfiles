#!/usr/bin/env bash
# IP address of the active connection (WiFi or LAN): polybar status / copy to the clipboard
# Usage: polybar-ip.sh [--status|--copy]
set -u

DF_MUTED="#7c6f64" DF_SUBTLE="#a89984"
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

notify() { notify-send -a network "$@" >/dev/null 2>&1; }

# Source address of the default route. `ip route get` only asks the kernel, nothing is sent.
current_ip() {
    local out
    out=$(ip -4 route get 1.1.1.1 2>/dev/null) || out=$(ip -6 route get 2606:4700:4700::1111 2>/dev/null) || return 1
    [[ "$out" =~ src\ ([0-9a-fA-F:.]+) ]] || return 1
    printf '%s' "${BASH_REMATCH[1]}"
}

case "${1:---status}" in
    --copy)
        if ! addr=$(current_ip); then
            notify "No IP address" "Not connected"
            exit 1
        fi
        printf '%s' "$addr" | xclip -selection clipboard
        notify "IP address copied" "$addr"
        ;;
    *)
        if addr=$(current_ip); then
            echo "%{F$DF_MUTED}󰩠  %{F$DF_SUBTLE}$addr%{F-}"
        else
            echo ""
        fi
        ;;
esac
