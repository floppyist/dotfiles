#!/usr/bin/env bash
# Power menu (Alt+Shift+e): lock, suspend, log out, reboot, shut down.
# Log out, reboot and shut down ask for confirmation ("Cancel" is preselected).
# Suspend goes through elogind, so xss-lock locks the screen before sleeping.
set -u

# Shared menu helper, resolved next to this script (works without ~/.local/bin in PATH)
ROFI_MENU="$(dirname "$(readlink -f "$0")")/rofi-menu"

notify() { notify-send -a system "$@" >/dev/null 2>&1; }

ACTIONS=(lock suspend logout reboot poweroff)
LABELS=("󰌾  Lock" "󰤄  Suspend" "󰍃  Log out" "󰜉  Reboot" "󰐥  Shut down")

up=$(uptime -p 2>/dev/null); up=${up#up }
IDX=$(printf '%s\n' "${LABELS[@]}" | "$ROFI_MENU" "power" "$(id -un)@$(uname -n)  ·  up ${up:-?}") || exit 0

confirm() {
    local choice
    choice=$(printf '%s\n' "󰅖  Cancel" "󰄬  $1" | "$ROFI_MENU" "power" "$1 now?") || return 1
    [[ "$choice" == 1 ]]
}

run() { "$@" || notify -u critical "Power action failed" "$*"; }

case "${ACTIONS[$IDX]}" in
    lock)     exec "$HOME/.local/bin/lock.sh" ;;
    suspend)  run loginctl suspend ;;
    logout)   confirm "Log out"   && run i3-msg exit ;;
    reboot)   confirm "Reboot"    && run loginctl reboot ;;
    poweroff) confirm "Shut down" && run loginctl poweroff ;;
esac
exit 0
