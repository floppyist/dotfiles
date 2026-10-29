# shellcheck shell=bash
# install/lib.sh  ·  shared by install.sh and install/*.sh: paths, the step output protocol,
# root, packages and what this machine has. Plain bash: it runs before anything is installed.

# ── Paths ─────────────────────────────────────────────────────────────────────────

SYSROOT=${DOTFILES_SYSROOT:-}        # tests only: system files and services below this directory
SV_DIR=$SYSROOT/etc/sv
RUNSV_DIR=$SYSROOT/var/service
CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
printf -v STAMP '%(%Y%m%d-%H%M%S)T' -1
LOG=$STATE_DIR/install-$STAMP.log

# JetBrainsMono Nerd Font: one family out of the Nerd Fonts release (7 MB) instead of the Void
# package nerd-fonts-ttf (all fonts, 1.5 GB). The checksum pins the file.
FONT_FAMILY="JetBrainsMono Nerd Font"
FONT_VERSION=v3.5.1
FONT_URL=https://github.com/ryanoasis/nerd-fonts/releases/download/$FONT_VERSION/JetBrainsMono.tar.xz
FONT_SHA256=04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf
FONT_DIR=$HOME/.local/share/fonts/JetBrainsMonoNerdFont

# ── Step output protocol ──────────────────────────────────────────────────────────
# Steps run with stdout and stderr in the log. Lines starting with @@ are messages for the
# installer and are not shown as log lines:
#   @@progress DONE TOTAL   progress of the running step
#   @@detail TEXT           what the step does right now
#   @@note TEXT             for the summary at the end
#   @@warn TEXT             the same, as a warning
#   @@reboot                the changes need a restart

say()         { printf '%s\n' "$*"; }
progress()    { printf '@@progress %d %d\n' "$1" "$2"; }
detail()      { printf '@@detail %s\n' "$*"; }
note()        { printf '@@note %s\n' "$*"; }
warn()        { printf '@@warn %s\n' "$*"; }
need_reboot() { printf '@@reboot\n'; }

# Runs a command as root. The installer asked for the password before (sudo -v), so this
# never prompts: steps run in the background.
as_root() {
    if (( EUID == 0 )); then "$@"; else sudo -n -- "$@"; fi
}

# 12345678 -> "12 MB"
human_size() {
    local b=${1:-0}
    if (( b >= 1073741824 )); then
        printf -v _HS '%d.%d GB' $(( b / 1073741824 )) $(( b % 1073741824 * 10 / 1073741824 ))
    elif (( b >= 1048576 )); then _HS="$(( b / 1048576 )) MB"
    else _HS="$(( (b + 1023) / 1024 )) kB"
    fi
}

# 95 -> "1 min 35 s"
human_time() {
    local s=${1:-0}
    if (( s >= 60 )); then _HT="$(( s / 60 )) min $(( s % 60 )) s"; else _HT="$s s"; fi
}

# ── Packages ──────────────────────────────────────────────────────────────────────

declare -A PKG_HAVE=()

pkg_scan() {
    PKG_HAVE=()
    local st pv _
    (( HAVE_XBPS )) || return 0
    while read -r st pv _; do
        [[ $st == ii ]] && PKG_HAVE[${pv%-*}]=1
    done < <(xbps-query -l 2>/dev/null)
}

pkg_have() { [[ -n ${PKG_HAVE[$1]-} ]]; }

# Dry run of a transaction (no root): TX_COUNT packages, TX_DL / TX_INST bytes, TX_PKGS names.
# Packages the repositories do not have are dropped and listed in TX_UNKNOWN.
xbps_dry() {
    TX_COUNT=0 TX_DL=0 TX_INST=0 TX_PKGS=() TX_UNKNOWN=()
    local pkgs=("$@") pv act _arch _repo inst dl out err i tries
    for (( tries = 0; tries < 25 && ${#pkgs[@]}; tries++ )); do
        out=$(xbps-install -n "${pkgs[@]}" 2>&1) && break
        err=$(sed -n "s/.*Package '\([^']*\)' not found in repository pool.*/\1/p" <<< "$out" | head -1)
        [[ -n $err ]] || break
        TX_UNKNOWN+=("$err")
        for i in "${!pkgs[@]}"; do [[ ${pkgs[i]} == "$err" ]] && unset 'pkgs[i]'; done
        pkgs=("${pkgs[@]}")
    done
    while read -r pv act _arch _repo inst dl; do
        [[ $act == @(install|update|configure|reinstall|downgrade) ]] || continue
        (( TX_COUNT++ ))
        TX_PKGS+=("${pv%-*}")
        [[ $inst =~ ^[0-9]+$ ]] && (( TX_INST += inst ))
        [[ $dl =~ ^[0-9]+$ ]] && (( TX_DL += dl ))
    done <<< "${out-}"
    XBPS_OK=("${pkgs[@]}")
}

# Turns the output of xbps-install into log lines and @@progress/@@detail messages.
# $1: number of packages in the transaction (0: unknown)
xbps_filter() {
    local total=$1 line dl=0 ver=0 unp=0 ok=0
    while IFS= read -r line; do
        line=${line##*$'\r'}
        printf '%s\n' "$line"
        case $line in
            *.xbps:*"[avg rate:"*)                  (( dl++ ));  detail "downloading $dl/$total" ;;
            *": verifying SHA256 hash"*)            (( ver++ )) ;;
            *": unpacking ..."*)                    (( unp++ )); detail "unpacking $unp/$total" ;;
            *": installed successfully."*|*": updated successfully."*)
                                                    (( ok++ ));  detail "configuring $ok/$total" ;;
            *) continue ;;
        esac
        (( total > 0 )) && progress $(( dl * 4 + ver + unp * 2 + ok * 3 )) $(( total * 10 ))
    done
}

# sudo xbps-install -y ARGS with progress. Options before the packages: -S (sync), -u (update).
xbps_install() {
    local opts=() dry=() total=0 pv act _
    while [[ ${1-} == -* ]]; do
        opts+=("$1")
        [[ $1 == -S ]] || dry+=("$1")    # the dry run (no root) uses the index of the last sync
        shift
    done
    while read -r pv act _; do
        [[ $act == @(install|update|configure|reinstall|downgrade) ]] && (( total++ ))
    done < <(xbps-install -n "${dry[@]}" "$@" 2>/dev/null)
    as_root stdbuf -oL -eL xbps-install -y "${opts[@]}" "$@" 2>&1 | xbps_filter "$total"
    return "${PIPESTATUS[0]}"
}

# ── This machine ──────────────────────────────────────────────────────────────────

detect() {
    local k v d class vendor drv name line l
    OS_ID="" OS_NAME=Linux
    if [[ -r /etc/os-release ]]; then
        while IFS='=' read -r k v; do
            v=${v#\"}; v=${v%\"}
            case $k in ID) OS_ID=$v ;; NAME) OS_NAME=$v ;; esac
        done < /etc/os-release
    fi
    HAVE_XBPS=0
    command -v xbps-install >/dev/null && command -v xbps-query >/dev/null && HAVE_XBPS=1
    ARCH=$(xbps-uhelper arch 2>/dev/null) || ARCH=$(uname -m)
    LIBC=glibc; [[ $ARCH == *-musl ]] && LIBC=musl
    USER_NAME=$(id -un)
    HOST_NAME=${HOSTNAME:-$(uname -n)}
    LOGIN_SHELL=""
    IFS=: read -r _ _ _ _ _ _ LOGIN_SHELL < <(getent passwd "$USER_NAME" 2>/dev/null)

    # Graphics: PCI display controllers (class 0x03xxxx). lspci (pciutils) only for the names.
    GPU_INTEL=0 GPU_AMD=0 GPU_AMDGPU=0 GPU_RADEON=0 GPU_NVIDIA=0 GPU_VM=0 GPU_NAMES=()
    for d in /sys/bus/pci/devices/*; do
        read -r class < "$d/class" 2>/dev/null || continue
        [[ $class == 0x03* ]] || continue
        read -r vendor < "$d/vendor"
        drv=""; [[ -e $d/driver ]] && { l=$(readlink "$d/driver"); drv=${l##*/}; }
        case $vendor in
            0x8086) GPU_INTEL=1;  name=Intel ;;
            0x1002) GPU_AMD=1;    name=AMD
                    # old cards (GCN 1 and before) run on the kernel driver radeon
                    if [[ $drv == radeon ]]; then GPU_RADEON=1; else GPU_AMDGPU=1; fi ;;
            0x10de) GPU_NVIDIA=1; name=NVIDIA ;;
            0x1af4|0x15ad|0x1b36|0x80ee|0x1234) GPU_VM=1; name="virtual GPU" ;;
            *) name="GPU $vendor" ;;
        esac
        if command -v lspci >/dev/null; then
            line=$(lspci -mm -s "${d##*/}" 2>/dev/null)
            if [[ $line =~ ^[^\"]*\"[^\"]*\"\ \"[^\"]*\"\ \"([^\"]*)\" ]]; then
                l=${BASH_REMATCH[1]%%[*}; l=${l%% }
                [[ -n $l && $name != "virtual GPU" ]] && name+=" $l"
            fi
        fi
        GPU_NAMES+=("$name${drv:+ ($drv)}")
    done
    GPU_LIST=""
    (( ${#GPU_NAMES[@]} )) && { printf -v GPU_LIST '%s, ' "${GPU_NAMES[@]}"; GPU_LIST=${GPU_LIST%, }; }
    NVIDIA_DRIVERS=(nouveau)
    [[ $LIBC == glibc && $ARCH == x86_64* ]] && NVIDIA_DRIVERS+=(nvidia nvidia580 nvidia470)
    NVIDIA_DRIVER=${NVIDIA_DRIVER:-}

    BACKLIGHT="" BATTERY="" BT_ADAPTER="" WIFI_IFS=()
    for d in /sys/class/backlight/*; do [[ -e $d ]] && { BACKLIGHT=${d##*/}; break; }; done
    for d in /sys/class/power_supply/BAT*; do [[ -e $d ]] && { BATTERY=${d##*/}; break; }; done
    for d in /sys/class/bluetooth/hci*; do [[ -e $d ]] && { BT_ADAPTER=${d##*/}; break; }; done
    for d in /sys/class/net/*/wireless; do [[ -e $d ]] && { l=${d%/wireless}; WIFI_IFS+=("${l##*/}"); }; done

    DM=""
    for k in lightdm sddm gdm lxdm slim emptty ly xdm greetd nodm; do
        [[ -e $RUNSV_DIR/$k ]] && { DM=$k; break; }
    done
    IN_X=0; [[ -n ${DISPLAY-} ]] && IN_X=1
    detect_net
}

# Network services that NetworkManager replaces (NET_OLD) and whether it is enabled (NM_ON)
detect_net() {
    local p
    NET_OLD=() NM_ON=0 WPA_CONFS=()
    for p in "$RUNSV_DIR"/dhcpcd "$RUNSV_DIR"/dhcpcd-* "$RUNSV_DIR"/wpa_supplicant "$RUNSV_DIR"/iwd \
             "$RUNSV_DIR"/connmand; do
        [[ -e $p || -L $p ]] && NET_OLD+=("${p##*/}")
    done
    [[ -e $RUNSV_DIR/NetworkManager || -L $RUNSV_DIR/NetworkManager ]] && NM_ON=1
    for p in "$SYSROOT"/etc/wpa_supplicant/wpa_supplicant*.conf; do
        [[ -f $p ]] && WPA_CONFS+=("$p")
    done
}

in_group() {
    local g
    for g in $(id -nG "$USER_NAME" 2>/dev/null); do [[ $g == "$1" ]] && return 0; done
    return 1
}

service_on() { [[ -e $RUNSV_DIR/$1 || -L $RUNSV_DIR/$1 ]]; }

# Both the regular and the bold JetBrainsMono Nerd Font are known to fontconfig
font_ok() {
    command -v fc-list >/dev/null || return 1
    [[ -n $(fc-list "$FONT_FAMILY:style=Regular" family 2>/dev/null) ]] &&
        [[ -n $(fc-list "$FONT_FAMILY:style=Bold" family 2>/dev/null) ]]
}

# The Firefox profile in use -> FF_PROFILE (empty if there is none). Prefers the profile of the
# installation (installs.ini, [Install…] in profiles.ini), then Default=1, then the first one.
ff_profile() {
    local base line sec path def first="" inst="" dflt=""
    FF_PROFILE=""
    for base in "$CONFIG/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [[ -f $base/profiles.ini ]] || continue
        sec="" path="" def=0
        while IFS= read -r line || [[ -n $line ]]; do
            line=${line%$'\r'}
            if [[ $line == \[*\] ]]; then
                ff_profile_take "$base"
                sec=$line path="" def=0
                continue
            fi
            case $line in
                Path=*)       path=${line#Path=} ;;
                Default=*)    [[ $sec == \[Install* ]] && path=${line#Default=} || def=${line#Default=} ;;
            esac
        done < "$base/profiles.ini"
        ff_profile_take "$base"
        FF_PROFILE=${inst:-${dflt:-$first}}
        [[ -n $FF_PROFILE ]] && return 0
    done
    return 1
}

# helper of ff_profile: the section that just ended (IsRelative=0 paths are absolute)
ff_profile_take() {
    [[ -n $path ]] || return 0
    local p=$path
    [[ $p == /* ]] || p=$1/$p
    [[ -d $p ]] || return 0
    case $sec in
        \[Install*) [[ -z $inst ]] && inst=$p ;;
        \[Profile*) (( def == 1 )) && [[ -z $dflt ]] && dflt=$p; [[ -z $first ]] && first=$p ;;
    esac
}
