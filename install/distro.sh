# shellcheck shell=bash
# install/distro.sh  ·  what differs between the distributions: the package manager, the init
# system (services), package names (install/pkgmap.sh) and the network services.
#
#   DISTRO   void arch debian ubuntu fedora alpine ("" = not supported: only the home directory)
#   PM       xbps pacman apt dnf apk
#   INIT     runit systemd openrc
#   HAVE_PM  1 if the package manager is there (steps with packages, services and /etc run)

# Oldest releases with recent enough packages (rofi, picom, polybar, fzf, Neovim)
declare -A DISTRO_MIN=( [debian]=13 [ubuntu]=26.04 [fedora]=43 [alpine]=3.23 )
declare -A DISTRO_TITLE=( [void]="Void Linux" [arch]="Arch Linux" [debian]=Debian [ubuntu]=Ubuntu
                          [fedora]=Fedora [alpine]="Alpine Linux" )

# /etc/os-release -> OS_ID OS_LIKE OS_VERSION OS_NAME, then DISTRO PM INIT HAVE_PM DISTRO_WARN
distro_detect() {
    local k v f=$SYSROOT/etc/os-release
    [[ -r $f ]] || f=/etc/os-release
    OS_ID="" OS_LIKE="" OS_VERSION="" OS_NAME=Linux
    if [[ -r $f ]]; then
        while IFS='=' read -r k v; do
            v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
            case $k in
                ID) OS_ID=$v ;; ID_LIKE) OS_LIKE=$v ;; VERSION_ID) OS_VERSION=$v ;; NAME) OS_NAME=$v ;;
            esac
        done < "$f"
    fi
    DISTRO="" PM="" DISTRO_WARN=""
    case " $OS_ID $OS_LIKE " in
        *" void "*)                DISTRO=void   PM=xbps ;;
        *" alpine "*)              DISTRO=alpine PM=apk ;;
        *" fedora "*)              DISTRO=fedora PM=dnf ;;
        *" arch "*|*" archlinux "*) DISTRO=arch  PM=pacman ;;
        *" ubuntu "*)              DISTRO=ubuntu PM=apt ;;
        *" debian "*)              DISTRO=debian PM=apt ;;
    esac
    # derivatives (Mint, Pop, EndeavourOS, ...) carry their own version numbers
    if [[ -n $DISTRO && $OS_ID != "$DISTRO" ]]; then
        DISTRO_WARN="$OS_NAME is treated as ${DISTRO_TITLE[$DISTRO]}: package names may differ."
    elif [[ -n ${DISTRO_MIN[$DISTRO]-} && -n $OS_VERSION ]] && version_lt "$OS_VERSION" "${DISTRO_MIN[$DISTRO]}"; then
        DISTRO_WARN="${DISTRO_TITLE[$DISTRO]} $OS_VERSION is older than ${DISTRO_MIN[$DISTRO]}: some programs are too old for this desktop."
    fi
    case $DISTRO in
        void) INIT=runit ;;
        alpine) INIT=openrc ;;
        "") INIT="" ;;
        *) INIT=systemd ;;
    esac
    HAVE_PM=0
    case $PM in
        xbps)   command -v xbps-install >/dev/null && command -v xbps-query >/dev/null && HAVE_PM=1 ;;
        pacman) command -v pacman >/dev/null && HAVE_PM=1 ;;
        apt)    command -v apt-get >/dev/null && command -v dpkg-query >/dev/null && HAVE_PM=1 ;;
        dnf)    command -v dnf >/dev/null && command -v rpm >/dev/null && HAVE_PM=1 ;;
        apk)    command -v apk >/dev/null && HAVE_PM=1 ;;
    esac
    # services of a systemd distribution in a container (tests): no systemd running
    [[ $INIT == systemd && ! -d /run/systemd/system && -z ${DOTFILES_FORCE_INIT-} ]] && INIT=none
    # the same for OpenRC (Alpine in a container)
    [[ $INIT == openrc && ! -x $SYSROOT/sbin/rc-update && -z ${DOTFILES_FORCE_INIT-} ]] && INIT=none
    [[ -n ${DOTFILES_FORCE_INIT-} ]] && INIT=$DOTFILES_FORCE_INIT
    # kept for older code paths
    HAVE_XBPS=0; [[ $PM == xbps ]] && HAVE_XBPS=$HAVE_PM
    pkgmap_load
}

# version_lt A B: A < B for dotted numbers (13 < 13.1, 3.9 < 3.23)
version_lt() {
    local IFS=. i a b
    read -ra a <<< "$1"; read -ra b <<< "$2"
    for (( i = 0; i < ${#a[@]} || i < ${#b[@]}; i++ )); do
        [[ ${a[i]:-0} =~ ^[0-9]+$ && ${b[i]:-0} =~ ^[0-9]+$ ]] || return 1
        (( 10#${a[i]:-0} < 10#${b[i]:-0} )) && return 0
        (( 10#${a[i]:-0} > 10#${b[i]:-0} )) && return 1
    done
    return 1
}

# The command that installs a package by hand (for messages)
pm_hint() {
    case $PM in
        xbps) _PH="xbps-install $1" ;; pacman) _PH="pacman -S $1" ;; apt) _PH="apt install $1" ;;
        dnf) _PH="dnf install $1" ;; apk) _PH="apk add $1" ;; *) _PH="install $1" ;;
    esac
}

# The group whose members may use sudo
sudo_group() {
    case $DISTRO in debian|ubuntu) _SG=sudo ;; *) _SG=wheel ;; esac
}

# ── Package names ─────────────────────────────────────────────────────────────────

declare -A PKGMAP=()

pkgmap_load() {
    local line col name v cols
    PKGMAP=()
    case $DISTRO in arch) col=1 ;; debian) col=2 ;; ubuntu) col=3 ;; fedora) col=4 ;; alpine) col=5 ;; *) return 0 ;; esac
    # shellcheck source=install/pkgmap.sh
    [[ -n ${PKGMAP_TABLE-} ]] || . "$DOTFILES/install/pkgmap.sh"
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
        IFS='|' read -ra cols <<< "$line"
        name=${cols[0]//[[:space:]]/}
        v=${cols[col]-=}
        if [[ $DISTRO == ubuntu ]]; then
            v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
            [[ $v == "~" ]] && v=${cols[2]}
        fi
        v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
        PKGMAP[$name]=${v:-=}
    done <<< "$PKGMAP_TABLE"
}

# Void's package name $1 -> _PM: this distribution's names ("@src:x" and "@bin:x" items for
# install/upstream.sh; empty: nothing to install). Names missing in the table stay as they are.
pkg_map() {
    _PM=()
    if [[ $DISTRO == void || -z $DISTRO ]]; then _PM=("$1"); return 0; fi
    local v=${PKGMAP[$1]-=}
    [[ $v == - ]] && return 0
    [[ $v == = ]] && v=$1
    local -; set -f
    # shellcheck disable=SC2206
    _PM=($v)
}

# ── Installed packages ────────────────────────────────────────────────────────────

declare -A PKG_HAVE=()

declare -A PKG_NOT=()

pkg_scan() {
    PKG_HAVE=() PKG_NOT=()
    (( HAVE_PM )) || return 0
    local st pv n _
    case $PM in
        xbps)
            while read -r st pv _; do [[ $st == ii ]] && PKG_HAVE[${pv%-*}]=1; done < <(xbps-query -l 2>/dev/null) ;;
        pacman)
            while read -r n; do PKG_HAVE[$n]=1; done < <(pacman -Qq 2>/dev/null) ;;
        apt)
            while read -r n st; do [[ $st == installed ]] && PKG_HAVE[${n%%:*}]=1; done \
                < <(dpkg-query -W -f '${Package} ${db:Status-Status}\n' 2>/dev/null) ;;
        dnf)
            while read -r n; do PKG_HAVE[$n]=1; done < <(rpm -qa --qf '%{NAME}\n' 2>/dev/null) ;;
        apk)
            while read -r n; do PKG_HAVE[$n]=1; done < <(apk info 2>/dev/null) ;;
    esac
}

pkg_have() {
    [[ -n ${PKG_HAVE[$1]-} ]] && return 0
    # apk: a name can be provided by another package (networkmanager-openvpn by its -gui variant)
    if [[ $PM == apk ]] && (( HAVE_PM )) && [[ -z ${PKG_NOT[$1]-} ]]; then
        if apk info -e "$1" >/dev/null 2>&1; then PKG_HAVE[$1]=1; return 0; fi
        PKG_NOT[$1]=1
    fi
    return 1
}

# Updates known from the last sync -> UPDATES ("" = unknown)
pm_updates() {
    local pv act _
    UPDATES=0
    (( HAVE_PM )) || return 0
    case $PM in
        xbps)   while read -r pv act _; do [[ $act == update ]] && (( UPDATES++ )); done < <(xbps-install -nu 2>/dev/null) ;;
        pacman) UPDATES=$(pacman -Qu 2>/dev/null | grep -c .) ;;
        apt)    UPDATES=$(apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null | grep -c '^Inst ') ;;
        apk)    UPDATES=$(apk version -l '<' 2>/dev/null | grep -vc '^Installed') ;;
        *)      UPDATES="" ;;
    esac
}

# ── Dry run (no root) ─────────────────────────────────────────────────────────────
# PKGS -> TX_COUNT (with dependencies; 0 = unknown), TX_DL / TX_INST bytes (0 = unknown),
# TX_UNKNOWN (names the repositories do not have, left out) and PM_OK (the rest)

pm_dry() {
    TX_COUNT=0 TX_DL=0 TX_INST=0 TX_PKGS=() TX_UNKNOWN=() PM_OK=("$@")
    (( HAVE_PM && $# )) || return 0
    case $PM in
        xbps) xbps_dry "$@"; PM_OK=("${XBPS_OK[@]}") ;;
        pacman|apt|apk) dry_loop "$@" ;;
        # dnf would download its metadata into the user's cache first: the install skips
        # unknown names itself (--skip-unavailable) and reports them
        dnf) ;;
    esac
}

# Runs the dry run of the package manager, drops the names it does not know and tries again
dry_loop() {
    local pkgs=("$@") out bad=() b i tries n name size line _
    for (( tries = 0; tries < 25 && ${#pkgs[@]}; tries++ )); do
        case $PM in
            pacman) out=$(pacman -Sp --print-format '%n %s' "${pkgs[@]}" 2>&1) ;;
            apt)    out=$(apt-get -s -o Debug::NoLocking=1 install "${pkgs[@]}" 2>&1) ;;
            apk)    out=$(apk add --simulate --no-progress "${pkgs[@]}" 2>&1) ;;
        esac
        bad=()
        case $PM in
            pacman) mapfile -t bad < <(sed -n 's/^error: target not found: \(.*\)$/\1/p' <<< "$out") ;;
            apt)    mapfile -t bad < <(sed -n -e "s/^E: Unable to locate package \(.*\)$/\1/p" \
                                             -e "s/^E: Package '\([^']*\)' has no installation candidate$/\1/p" <<< "$out") ;;
            apk)    mapfile -t bad < <(sed -n 's/^ *\([^ ]*\) (no such package):$/\1/p' <<< "$out") ;;
        esac
        (( ${#bad[@]} )) || break
        for b in "${bad[@]}"; do
            TX_UNKNOWN+=("$b")
            for i in "${!pkgs[@]}"; do [[ ${pkgs[i]} == "$b" ]] && unset 'pkgs[i]'; done
        done
        pkgs=("${pkgs[@]}")
    done
    PM_OK=("${pkgs[@]}")
    (( ${#pkgs[@]} )) || return 0
    case $PM in
        pacman)
            while read -r name size _; do
                [[ $name == error:* || -z $name ]] && continue
                (( TX_COUNT++ )); TX_PKGS+=("$name")
                [[ $size =~ ^[0-9]+$ ]] && (( TX_DL += size ))
            done <<< "$out" ;;
        apt)
            while read -r n name _; do
                [[ $n == Inst ]] || continue
                (( TX_COUNT++ )); TX_PKGS+=("$name")
            done <<< "$out" ;;
        apk)
            while IFS= read -r line; do
                [[ $line =~ ^\([0-9]+/[0-9]+\)\ Installing\ ([^ ]+) ]] || continue
                (( TX_COUNT++ )); TX_PKGS+=("${BASH_REMATCH[1]}")
            done <<< "$out" ;;
    esac
}

# ── Installing (root) ─────────────────────────────────────────────────────────────

# Syncs the package lists (before the packages step)
pm_sync() {
    case $PM in
        xbps) as_root xbps-install -S 2>&1 ;;
        apt)  as_root env DEBIAN_FRONTEND=noninteractive apt-get update 2>&1 ;;
        apk)  as_root apk update 2>&1 ;;
        *)    return 0 ;;
    esac
}

APT_OPTS=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# stdbuf (line by line output into the log) -> LB; Alpine has it only with coreutils
line_buffered() {
    LB=()
    command -v stdbuf >/dev/null && LB=(stdbuf -oL)
}

# Installs PKGS with progress (@@progress/@@detail); unknown names were dropped by pm_dry
pm_install() {
    local total=${TX_COUNT:-0} rc
    line_buffered
    (( total )) || total=$#
    case $PM in
        xbps)   xbps_install "$@"; return ;;
        # Arch: never a partial upgrade (installing against an old system breaks it)
        pacman) as_root "${LB[@]}" pacman -Syu --needed --noconfirm "$@" 2>&1 | pm_filter "$total" ;;
        apt)    as_root env DEBIAN_FRONTEND=noninteractive "${LB[@]}" apt-get install "${APT_OPTS[@]}" "$@" 2>&1 | pm_filter "$total" ;;
        dnf)    as_root "${LB[@]}" dnf install -y --skip-unavailable "$@" 2>&1 | pm_filter "$total" ;;
        apk)    as_root "${LB[@]}" apk add --no-progress "$@" 2>&1 | pm_filter "$total" ;;
        *)      return 1 ;;
    esac
    rc=${PIPESTATUS[0]}
    return "$rc"
}

# Updates the whole system
pm_upgrade() {
    line_buffered
    case $PM in
        xbps)
            detail "updating xbps"
            xbps_install -u xbps || return 1
            local n=0 pv act _
            while read -r pv act _; do [[ $act == update ]] && (( n++ )); done < <(xbps-install -nu 2>/dev/null)
            if (( n == 0 )); then say "the system is up to date"; return 0; fi
            detail "updating $n packages"
            xbps_install -u ;;
        pacman) as_root "${LB[@]}" pacman -Syu --noconfirm 2>&1 | pm_filter 0; return "${PIPESTATUS[0]}" ;;
        apt)    as_root env DEBIAN_FRONTEND=noninteractive "${LB[@]}" apt-get full-upgrade "${APT_OPTS[@]}" 2>&1 | pm_filter 0
                return "${PIPESTATUS[0]}" ;;
        dnf)    as_root "${LB[@]}" dnf upgrade -y --refresh 2>&1 | pm_filter 0; return "${PIPESTATUS[0]}" ;;
        apk)    as_root "${LB[@]}" apk upgrade --no-progress 2>&1 | pm_filter 0; return "${PIPESTATUS[0]}" ;;
    esac
}

# Output of pacman/apt/dnf/apk -> log lines, @@detail and @@progress (unknown names: @@warn)
pm_filter() {
    local total=$1 line n=0 dl=0 m
    while IFS= read -r line; do
        line=${line##*$'\r'}
        printf '%s\n' "$line"
        case $line in
            # pacman "(3/41) installing foo", apk "(3/41) Installing foo (1.0-r0)"
            "("*/*") "[Ii]nstalling" "*|"("*/*") "[Uu]pgrading" "*)
                if [[ $line =~ ^\(([0-9]+)/([0-9]+)\)\ [A-Za-z]+\ ([^ ]+) ]]; then
                    detail "installing ${BASH_REMATCH[1]}/${BASH_REMATCH[2]}: ${BASH_REMATCH[3]}"
                    progress "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                fi ;;
            # apt
            Get:*)          (( dl++ )); detail "downloading $dl${total:+/$total}" ;;
            "Setting up "*) (( n++ )); m=${line#Setting up }; detail "setting up $n/$total: ${m%% *}"
                            (( total > 0 )) && progress "$n" "$total" ;;
            # dnf5
            *"No match for argument: "*) warn "Package ${line##*argument: } is not in the repository, left out" ;;
            "["*"/"*"] "*)  if [[ $line =~ ^\[\ *([0-9]+)/([0-9]+)\]\ (.*)$ ]]; then
                                detail "${BASH_REMATCH[3]:0:60}"
                                progress "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                            fi ;;
        esac
    done
}

# Alpine: the community repository (i3, polybar, ...) is commented out after a plain install
apk_community_off() {
    local f=$SYSROOT/etc/apk/repositories
    [[ $PM == apk && -r $f ]] || return 1
    grep -qE '^[[:space:]]*[^#].*/community[[:space:]]*$' "$f" && return 1
    grep -qE '^[[:space:]]*#.*/community[[:space:]]*$' "$f"
}

apk_community_on() {
    local tmp
    tmp=$(mktemp) || return 1
    # the line that belongs to the same release as main (not edge)
    sed -E '/\/edge\//b; s|^[[:space:]]*#[[:space:]]*(.*/community[[:space:]]*)$|\1|' \
        "$SYSROOT/etc/apk/repositories" > "$tmp" &&
        as_root install -m644 "$tmp" "$SYSROOT/etc/apk/repositories"
    local rc=$?
    rm -f "$tmp"
    return "$rc"
}

# ── Services ──────────────────────────────────────────────────────────────────────
# Logical names: dbus elogind bluetooth networkmanager udev. svc_name -> _SN (empty: the init
# system has it always, nothing to enable)

svc_name() {
    _SN=""
    case $INIT:$1 in
        runit:dbus) _SN=dbus ;; runit:elogind) _SN=elogind ;; runit:bluetooth) _SN=bluetoothd ;;
        runit:networkmanager) _SN=NetworkManager ;;
        systemd:bluetooth) _SN=bluetooth ;; systemd:networkmanager) _SN=NetworkManager ;;
        openrc:dbus) _SN=dbus ;; openrc:elogind) _SN=elogind ;; openrc:bluetooth) _SN=bluetooth ;;
        openrc:networkmanager) _SN=networkmanager ;; openrc:udev) _SN=udev ;;
    esac
}

# The service is installed
svc_exists() {
    case $INIT in
        runit)   [[ -d $SV_DIR/$1 ]] ;;
        systemd) systemctl cat "$1.service" >/dev/null 2>&1 ;;
        openrc)  [[ -e $SYSROOT/etc/init.d/$1 ]] ;;
        *)       return 1 ;;
    esac
}

# The service starts with the system
svc_enabled() {
    case $INIT in
        runit)   [[ -e $RUNSV_DIR/$1 || -L $RUNSV_DIR/$1 ]] ;;
        systemd) systemctl is-enabled --quiet "$1.service" 2>/dev/null ;;
        openrc)  local l; for l in "$SYSROOT"/etc/runlevels/*/"$1"; do [[ -e $l || -L $l ]] && return 0; done; return 1 ;;
        *)       return 1 ;;
    esac
}

# Enables and starts it (openrc: runlevel $2, default "default")
svc_enable() {
    case $INIT in
        runit)   as_root ln -s "$SV_DIR/$1" "$RUNSV_DIR/" ;;
        systemd) as_root systemctl enable --now "$1.service" 2>&1 ;;
        openrc)  as_root rc-update add "$1" "${2:-default}" 2>&1 && { as_root rc-service "$1" start 2>&1; true; } ;;
        *)       return 1 ;;
    esac
}

# Stops it and takes it out of the boot
svc_disable() {
    case $INIT in
        runit)   as_root sv down "$RUNSV_DIR/$1" >/dev/null 2>&1; as_root rm -f "$RUNSV_DIR/$1" ;;
        systemd) as_root systemctl disable --now "$1.service" 2>&1 ;;
        openrc)  as_root rc-service "$1" stop >/dev/null 2>&1; as_root rc-update del "$1" 2>&1 ;;
        *)       return 1 ;;
    esac
}

# ── Network services ──────────────────────────────────────────────────────────────
# NET_OLD: services that manage the network instead of NetworkManager; NM_ON: NetworkManager is
# enabled; WPA_CONFS: wpa_supplicant configs (Void: their networks move to NetworkManager)

detect_net() {
    local p s
    NET_OLD=() NM_ON=0 WPA_CONFS=()
    case $INIT in
        runit)
            for p in "$RUNSV_DIR"/dhcpcd "$RUNSV_DIR"/dhcpcd-* "$RUNSV_DIR"/wpa_supplicant "$RUNSV_DIR"/iwd \
                     "$RUNSV_DIR"/connmand; do
                [[ -e $p || -L $p ]] && NET_OLD+=("${p##*/}")
            done
            [[ -e $RUNSV_DIR/NetworkManager || -L $RUNSV_DIR/NetworkManager ]] && NM_ON=1
            for p in "$SYSROOT"/etc/wpa_supplicant/wpa_supplicant*.conf; do
                [[ -f $p ]] && WPA_CONFS+=("$p")
            done ;;
        systemd)
            svc_enabled NetworkManager && NM_ON=1
            for s in systemd-networkd iwd connman dhcpcd; do svc_enabled "$s" && NET_OLD+=("$s"); done
            # wpa_supplicant@wlan0 (its own WiFi setup; the plain wpa_supplicant.service is the one
            # NetworkManager uses over D-Bus)
            for p in "$SYSROOT"/etc/systemd/system/multi-user.target.wants/wpa_supplicant@*.service; do
                [[ -e $p || -L $p ]] && { s=${p##*/}; NET_OLD+=("${s%.service}"); }
            done
            # Debian's ifupdown with an interface besides lo (an empty config is the default)
            svc_enabled networking && ifupdown_used && NET_OLD+=(networking) ;;
        openrc)
            svc_enabled networkmanager && NM_ON=1
            for s in wpa_supplicant iwd dhcpcd connman; do svc_enabled "$s" && NET_OLD+=("$s"); done
            svc_enabled networking && ifupdown_used && NET_OLD+=(networking) ;;
    esac
    # systemd-networkd without a config does nothing
    if [[ " ${NET_OLD[*]} " == *" systemd-networkd "* ]]; then
        local cfg=("$SYSROOT"/etc/systemd/network/*.network "$SYSROOT"/run/systemd/network/*.network)
        [[ -e ${cfg[0]} || -e ${cfg[1]-} ]] || NET_OLD=("${NET_OLD[@]/systemd-networkd}")
        local keep=() x; for x in "${NET_OLD[@]}"; do [[ -n $x ]] && keep+=("$x"); done; NET_OLD=("${keep[@]}")
    fi
}

# /etc/network/interfaces (and interfaces.d) configure an interface besides lo
ifupdown_used() {
    local f
    for f in "$SYSROOT"/etc/network/interfaces "$SYSROOT"/etc/network/interfaces.d/*; do
        [[ -f $f ]] || continue
        grep -qE '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+([^l]|l[^o]|lo[^[:space:]])' "$f" && return 0
    done
    return 1
}

# The enabled display manager -> DM
detect_dm() {
    local k l
    DM=""
    case $INIT in
        runit)
            for k in lightdm sddm gdm lxdm slim emptty ly xdm greetd nodm; do
                [[ -e $RUNSV_DIR/$k ]] && { DM=$k; return 0; }
            done ;;
        systemd)
            l=$(readlink "$SYSROOT/etc/systemd/system/display-manager.service" 2>/dev/null)
            [[ -n $l ]] && { DM=${l##*/}; DM=${DM%.service}; } ;;
        openrc)
            for k in lightdm sddm gdm lxdm slim greetd xdm; do
                [[ -e $SYSROOT/etc/runlevels/default/$k ]] && { DM=$k; return 0; }
            done ;;
    esac
}
