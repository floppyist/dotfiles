#!/usr/bin/env bash
# install.sh  ·  sets up this desktop on Void Linux, from a fresh i3 to everything in place.
#
#   ./install.sh                 the installer: complete installation, single modules or links
#   ./install.sh all             complete installation without the menus
#   ./install.sh modules LIST    these modules (comma separated, see `list`), without the menus
#   ./install.sh plan [LIST]     what would happen (all modules without LIST); changes nothing
#   ./install.sh list            the modules and their state on this machine
#   ./install.sh dualboot-clean  remove the installer entry and partition of a second system again
#   ./install.sh links           only link the files and generate the theme (after git pull; no root)
#
#   -y, --yes                    do not ask before starting (all, modules)
#   --skip LIST                  leave these modules out (all)
#   --nvidia DRIVER              nouveau (default), nvidia, nvidia580 or nvidia470
#   --fix LIST                   hardware fixes (comma separated, see `list`): turns the module `fixes` on and
#                                chooses exactly these (default: the ones this machine needs)
#   --other-os SYSTEM            sets up a second system (arch, debian, ubuntu, fedora, alpine, windows):
#                                a partition from unallocated space, the ISO, a GRUB entry; turns `dualboot` on
#   --disk DEVICE                the disk for it (default: the only one with enough free space)
#   --windows-iso FILE           the Windows ISO for --other-os windows
#   --kernel-version VERSION     the version of the `kernel` module, like 6.18.60 (default: the newest
#                                of the running series); the module is never part of `all`
#
# Without a terminal and without arguments it runs `links`, like earlier versions.
# Run it as your user: it sets up your home directory and asks for sudo itself. Every step is
# idempotent, so it can run again at any time (after git pull, after adding a module).
# The parts live in install/: lib.sh (helpers), links.sh, modules.sh, steps.sh, tui.sh.
set -o pipefail
shopt -s extglob

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=install/lib.sh
. "$DOTFILES/install/lib.sh"
# shellcheck source=install/links.sh
. "$DOTFILES/install/links.sh"
# shellcheck source=install/modules.sh
. "$DOTFILES/install/modules.sh"
# shellcheck source=install/dualboot.sh
. "$DOTFILES/install/dualboot.sh"
# shellcheck source=install/steps.sh
. "$DOTFILES/install/steps.sh"
# shellcheck source=install/tui.sh
. "$DOTFILES/install/tui.sh"

usage() { sed -n '2,/^[^#]/{/^#/{s/^# \{0,1\}//;p}}' "$0"; }

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

cleanup() {
    tui_stop
    final_summary
    if (( ${WANT_REBOOT:-0} )); then
        printf 'Rebooting...\n'
        sudo reboot
        return
    fi
    # The root permission ends with the installer (sudo would keep it for some minutes)
    if [[ -n ${SUDO_KEEP-} ]]; then
        kill "$SUDO_KEEP" 2>/dev/null
        sudo -k
    fi
    if [[ -n ${FLOW_DONE-} && -s $LOG && -z ${FINAL_TITLE-} ]]; then
        printf 'dotfiles: the log of this run is %s\n' "$LOG"
    fi
    if (( ${WANT_STARTX:-0} )); then
        printf 'Starting the desktop...\n'
        exec startx
    fi
}

# What this machine has and what each module would do
scan_machine() {
    local pv act _
    detect
    pkg_scan
    UPDATES=0
    if (( HAVE_XBPS )); then
        while read -r pv act _; do [[ $act == update ]] && (( UPDATES++ )); done < <(xbps-install -nu 2>/dev/null)
    fi
    mods_default
    mods_scan
    TOTAL_DL=0
    sel_pkgs
    if (( HAVE_XBPS && ${#SM[@]} )); then xbps_dry "${SM[@]}"; TOTAL_DL=$TX_DL; fi
}

log_header() {
    local m sel=()
    mkdir -p "$STATE_DIR"
    # private: it lists the WiFi networks that were moved to NetworkManager
    (umask 077; : >> "$LOG")
    for m in "${MODULES[@]}"; do (( ${SEL[$m]:-0} )) && sel+=("$m"); done
    {
        printf 'dotfiles install.sh  %(%F %T)T\n' -1
        printf 'repository  %s (%s)\n' "$DOTFILES" "$(git -C "$DOTFILES" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)"
        printf 'system      %s %s, user %s, shell %s\n' "$OS_NAME" "$ARCH" "$USER_NAME" "$LOGIN_SHELL"
        printf 'graphics    %s%s\n' "${GPU_LIST:-none}" "$( (( GPU_NVIDIA )) && echo " (driver $NVIDIA_DRIVER)")"
        printf 'modules     %s\n' "${sel[*]}"
        (( ${SEL[kernel]:-0} )) && printf 'kernel      %s\n' "${KERNEL_VERSION:-newest of the running series}"
        (( ${SEL[fixes]:-0} )) && { fixes_chosen; printf 'fixes       %s\n' "${FIXC[*]}"; }
        printf 'boot        %s, other systems: %s\n' "$BOOTLOADER" "${OTHER_OS[*]:-none}"
        printf 'steps       %s\n' "${SS[*]}"
        printf 'packages    %s\n' "${SM[*]}"
    } >> "$LOG"
}

# ── Without the menus ─────────────────────────────────────────────────────────────

# Colors for plain output (the same palette as the installer, if this is a terminal)
cli_colors() {
    if [[ -t 1 ]]; then
        tui_theme
    else
        local t
        declare -gA F=() B=()
        for t in bg surface overlay fg subtle muted accent accent_text on_accent ok warn err info; do F[$t]=""; B[$t]=""; done
        BOLD="" NOBOLD="" N=""
        tui_glyphs
    fi
    [[ -t 1 ]] && N=$'\e[0m'   # no background color outside the full-screen installer
}

cli_width() {
    local s=""
    [[ -t 1 ]] && s=$(stty size 2>/dev/null)
    DW=${s##* }
    [[ $DW =~ ^[0-9]+$ ]] || DW=100
    DW=$(( DW > 110 ? 100 : DW - 4 ))
}

# Prints DL (built by a d_* function) to stdout
cli_print() {
    local l
    for l in "${DL[@]}"; do printf '  %s%s\n' "$l" "$N"; done
}

# Runs one step, its output indented; messages (lib.sh protocol) collected
cli_step() {
    local st=$1 rc=1 line
    printf '\n%s%s %s%s\n' "${F[accent_text]}" "$G_BAR" "$BOLD${F[fg]}${STEP_TITLE[$st]}" "$N"
    printf '\n==> %s\n' "${STEP_TITLE[$st]}" >> "$LOG"
    while IFS= read -r line; do
        [[ $line == "@@exit "* ]] && { rc=${line#@@exit }; continue; }
        printf '%s\n' "$line" >> "$LOG"
        case $line in
            "@@progress "*|"@@detail "*) ;;
            "@@note "*)  NOTES+=("${line#@@note }") ;;
            "@@warn "*)  WARNINGS+=("${line#@@warn }"); printf '    %s! %s%s\n' "${F[warn]}" "${line#@@warn }" "$N" ;;
            "@@reboot")  REBOOT=1 ;;
            *)           line=${line##*$'\r'}
                         line=${line//$'\e'\[*([0-9;?])[@-~]/}
                         printf '    %s%s%s\n' "${F[muted]}" "${line//[[:cntrl:]]/}" "$N" ;;
        esac
    done < <( trap '' HUP; "run_$st" </dev/null 2>&1; printf '\n@@exit %d\n' "$?" )
    [[ $rc =~ ^[0-9]+$ ]] || rc=1
    printf '<== %s: %s\n' "${STEP_TITLE[$st]}" "$( (( rc )) && echo "failed ($rc)" || echo ok)" >> "$LOG"
    return "$rc"
}

cli_install() {
    local st failed=() l
    cli_colors
    plan_compute
    PLAN_TITLE="What happens"
    cli_width
    build_plan
    printf '\n%s%s%s\n\n' "$BOLD${F[fg]}" "$PLAN_TITLE" "$N"
    cli_print
    if (( ! YES )); then
        [[ -t 0 ]] || die "not a terminal: add --yes to start without asking"
        printf '\nStart? [y/N] '
        read -r l
        [[ $l == [yYjJ]* ]] || { echo "Nothing changed."; return 0; }
    fi
    log_header
    if sel_needs_root && (( EUID != 0 )); then
        command -v sudo >/dev/null || die "sudo is not installed"
        sudo -v || die "sudo failed"
        sudo_keepalive
    fi
    NOTES=() WARNINGS=() REBOOT=0
    # Ctrl+C (or a closed terminal) stops after the running step: an xbps transaction is never
    # cut off halfway (the step itself ignores both signals)
    CLI_STOP=0
    trap 'CLI_STOP=1; printf "\n    stopping after this step\n" >&2' INT
    trap 'CLI_STOP=1' HUP
    for st in "${SS[@]}"; do
        (( CLI_STOP )) && { echo "Stopped before: ${STEP_TITLE[$st]}"; break; }
        if ! cli_step "$st"; then
            failed+=("${STEP_TITLE[$st]}")
            printf '    %s%s %s failed%s\n' "${F[err]}" "$G_FAIL" "${STEP_TITLE[$st]}" "$N"
            [[ $st == @(update|packages) ]] && { echo "Stopping: the next steps need the packages."; break; }
        fi
    done
    trap 'exit 130' INT HUP
    FLOW_DONE=1
    echo
    if (( ${#failed[@]} )); then
        printf '%sFailed: %s%s\n' "${F[err]}" "${failed[*]}" "$N"
    elif (( CLI_STOP )); then
        printf '%sStopped.%s Run it again to finish: steps that are done are skipped.\n' "${F[warn]}" "$N"
    else
        printf '%s%s Done%s\n' "${F[ok]}" "$G_OK" "$N"
    fi
    for l in "${NOTES[@]}"; do printf '  %s %s\n' "$G_DOT" "$l"; done
    for l in "${WARNINGS[@]}"; do printf '  %s! %s%s\n' "${F[warn]}" "$l" "$N"; done
    (( REBOOT )) && printf '  %s Restart the computer: new services, groups and the login shell take effect then.\n' "$G_DOT"
    (( ${#failed[@]} == 0 && ! CLI_STOP ))
}

cli_list() {
    local m
    cli_colors
    for m in "${MODULES[@]}"; do
        mod_status "$m"
        printf '%s %-10s %-18s %s%s%s\n' "$( (( SEL[$m] )) && echo "$G_ON" || echo "$G_OFF")" "$m" \
            "${M_TITLE[$m]}" "$_STC" "$_ST" "$N"
    done
}

# LIST (comma separated) -> SEL; core is always part of it
select_modules() {
    local m want
    local -A ok=()
    for m in "${MODULES[@]}"; do ok[$m]=1; SEL[$m]=0; done
    SEL[core]=1
    IFS=, read -ra want <<< "$1"
    for m in "${want[@]}"; do
        [[ -n ${ok[$m]-} ]] || die "unknown module '$m' (see ./install.sh list)"
        SEL[$m]=1
    done
}

# --other-os, --disk, --windows-iso -> DUAL_TARGET DUAL_DISK WIN_ISO
cli_other_os() {
    local id ok=0 i
    for id in "${OSES[@]}"; do [[ $id == "$OTHER_OS_ARG" ]] && ok=1; done
    (( ok )) || die "unknown system '$OTHER_OS_ARG' (${OSES[*]})"
    DUAL_TARGET=$OTHER_OS_ARG
    SEL[dualboot]=1; M_OFF[dualboot]=""
    othersys_gib "$DUAL_TARGET"
    if [[ $DUAL_TARGET == windows ]]; then
        [[ -n ${WINISO_ARG-} && -r $WINISO_ARG ]] || die "windows: --windows-iso FILE (a readable Windows ISO)"
        WIN_ISO=$(readlink -f "$WINISO_ARG")
    fi
    if [[ -n ${DISK_ARG-} ]]; then
        [[ $DISK_ARG == /dev/* && -b $DISK_ARG ]] || die "--disk: a block device like /dev/sda"
        DUAL_DISK=$DISK_ARG
    else
        detect_disks; disks_with_room "$OS_TOTAL"
        (( ${#DISK_OK[@]} )) || die "no disk has $OS_TOTAL GB of unallocated space (free some in Windows or with gparted)"
        local nonusb=()
        for i in "${DISK_OK[@]}"; do [[ ${DISK_TRAN[i]} == usb ]] || nonusb+=("$i"); done
        (( ${#nonusb[@]} == 1 )) || die "several disks have room: choose one with --disk (${DISKS[*]})"
        DUAL_DISK=${DISKS[${nonusb[0]}]}
    fi
    mods_scan
}

# The old install.sh: links and theme, plain output
cli_links() {
    detect
    run_links || die "linking failed"
    if command -v python3 >/dev/null; then
        "$DOTFILES/scripts/dotfiles" apply --no-reload || die "dotfiles apply failed"
    else
        echo "python3 is missing: the theme was not generated (run ./install.sh for the packages)"
    fi
    echo
    echo "Done. Packages, services, font, Firefox and the rest: ./install.sh (or ./install.sh all)."
}

main() {
    local cmd="" list="" skip="" m want
    YES=0
    while (( $# )); do
        case $1 in
            -h|--help)    usage; exit 0 ;;
            -y|--yes)     YES=1 ;;
            --skip)       skip=${2-}; shift ;;
            --skip=*)     skip=${1#*=} ;;
            --nvidia)     NVIDIA_DRIVER=${2-}; shift ;;
            --nvidia=*)   NVIDIA_DRIVER=${1#*=} ;;
            --other-os)   OTHER_OS_ARG=${2-}; shift ;;
            --other-os=*) OTHER_OS_ARG=${1#*=} ;;
            --disk)       DISK_ARG=${2-}; shift ;;
            --disk=*)     DISK_ARG=${1#*=} ;;
            --windows-iso)   WINISO_ARG=${2-}; shift ;;
            --windows-iso=*) WINISO_ARG=${1#*=} ;;
            --fix)        FIX_LIST=${2-}; shift ;;
            --fix=*)      FIX_LIST=${1#*=} ;;
            --kernel-version)   KERNEL_VERSION=${2-}; shift ;;
            --kernel-version=*) KERNEL_VERSION=${1#*=} ;;
            all|links|list|tui|dualboot-clean) [[ -z $cmd ]] || die "one command only"; cmd=$1 ;;
            modules|plan) [[ -z $cmd ]] || die "one command only"; cmd=$1
                          [[ ${2-} != -* && -n ${2-} ]] && { list=$2; shift; } ;;
            *)            die "unknown argument '$1' (see --help)" ;;
        esac
        shift
    done
    if [[ -n ${NVIDIA_DRIVER-} && $NVIDIA_DRIVER != @(nouveau|nvidia|nvidia580|nvidia470) ]]; then
        die "unknown NVIDIA driver '$NVIDIA_DRIVER'"
    fi
    if [[ -n ${FIX_LIST-} && ! $FIX_LIST =~ ^[a-z0-9-]+(,[a-z0-9-]+)*$ ]]; then
        die "invalid fix list '$FIX_LIST'"
    fi
    if [[ -n ${KERNEL_VERSION-} && ! $KERNEL_VERSION =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        die "invalid kernel version '$KERNEL_VERSION' (like 6.18.60)"
    fi
    (( EUID == 0 )) && die "run it as your user, not as root: it sets up your home directory and uses sudo itself"
    if [[ -z $cmd ]]; then
        if [[ -t 0 && -t 1 ]]; then cmd=tui; else cmd=links; fi
    fi
    mkdir -p "$STATE_DIR" || die "cannot create $STATE_DIR"
    trap cleanup EXIT
    trap 'exit 130' INT TERM HUP

    case $cmd in
        links) cli_links ;;
        dualboot-clean) dualboot_clean ;;
        tui)   tui_main ;;
        list)  scan_machine; cli_list ;;
        all|modules|plan)
            scan_machine
            if [[ $cmd == modules || ( $cmd == plan && -n $list ) ]]; then
                [[ -n $list ]] || die "modules: which ones? (see ./install.sh list)"
                select_modules "$list"
            fi
            [[ -n ${OTHER_OS_ARG-} ]] && cli_other_os
            if [[ -n ${FIX_LIST-} ]]; then
                local f ok
                for f in "${FIXES[@]}"; do FIX_SEL[$f]=0; done
                IFS=, read -ra want <<< "$FIX_LIST"
                for f in "${want[@]}"; do
                    ok=0; for m in "${FIXES[@]}"; do [[ $m == "$f" ]] && ok=1; done
                    (( ok )) || die "unknown fix '$f' (${FIXES[*]})"
                    FIX_SEL[$f]=1
                done
                SEL[fixes]=1
            fi
            if [[ -n $skip ]]; then
                IFS=, read -ra skip <<< "$skip"
                for m in "${skip[@]}"; do
                    [[ $m == core ]] && die "core cannot be skipped"
                    [[ -n ${M_TITLE[$m]-} ]] || die "unknown module '$m'"
                    SEL[$m]=0
                done
            fi
            if [[ $cmd == plan ]]; then
                cli_colors
                plan_compute
                cli_width
                build_plan
                cli_print
            else
                cli_install
            fi ;;
    esac
}

# sourced (tests): only the functions
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
