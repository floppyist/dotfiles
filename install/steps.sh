# shellcheck shell=bash
# install/steps.sh  ·  the steps of the installation. For every step:
#   plan_<step> [MODULE]  fills PLAN with what it would do ("!" in front: a warning) and
#                          returns 1 if there is nothing to do; MODULE limits it to one module
#   run_<step>            does it; runs in the background, output in the log (lib.sh protocol)

STEP_ORDER=(update packages font services backlight alsa shell links firefox mail theme nvim autostart network)

declare -A STEP_TITLE=(
    [update]="System update"  [packages]="Packages"        [font]="Font"
    [services]="Services"     [backlight]="Backlight"      [alsa]="ALSA to PipeWire"
    [shell]="Login shell"     [links]="Links"              [firefox]="Firefox"
    [mail]="neomutt"          [theme]="Theme"              [nvim]="Neovim plugins"
    [autostart]="Start X on login"                         [network]="NetworkManager"
)
# share of the whole installation, for the progress bar
declare -A STEP_WEIGHT=(
    [update]=12 [packages]=40 [font]=4 [services]=1 [backlight]=1 [alsa]=1 [shell]=1
    [links]=3 [firefox]=3 [mail]=1 [theme]=5 [nvim]=14 [autostart]=1 [network]=3
)
declare -A STEP_ROOT=( [update]=1 [packages]=1 [services]=1 [backlight]=1 [alsa]=1 [shell]=1 [network]=1 )

plan_step() {
    PLAN=()
    "plan_$1" "${2-}"
}

# ── System update ─────────────────────────────────────────────────────────────────

plan_update() {
    PLAN=("sync the repositories, update xbps, then every installed package")
    case ${UPDATES:-0} in
        0) ;;
        1) PLAN+=("1 update is known from the last sync") ;;
        *) PLAN+=("$UPDATES updates are known from the last sync") ;;
    esac
    return 0
}

run_update() {
    detail "syncing the repositories"
    as_root xbps-install -S 2>&1 || return 1
    detail "updating xbps"
    xbps_install -u xbps || return 1
    local n=0 pv act _
    while read -r pv act _; do [[ $act == update ]] && (( n++ )); done < <(xbps-install -nu 2>/dev/null)
    if (( n == 0 )); then say "the system is up to date"; return 0; fi
    detail "updating $n packages"
    xbps_install -u
}

# ── Packages ──────────────────────────────────────────────────────────────────────

plan_packages() {
    (( ${#SM[@]} )) || return 1
    PLAN=("${SM[*]}")
}

run_packages() {
    pkg_scan
    sel_pkgs
    local p repos=() rest=()
    for p in "${SM[@]}"; do
        if [[ $p == void-repo-* ]]; then repos+=("$p"); else rest+=("$p"); fi
    done
    # A repository package (nonfree for NVIDIA) has to be installed and synced first
    if (( ${#repos[@]} )); then
        detail "adding ${repos[*]}"
        xbps_install -S "${repos[@]}" || return 1
        as_root xbps-install -S 2>&1 || return 1
    fi
    (( ${#rest[@]} )) || { say "every package is installed"; return 0; }
    detail "syncing the repositories"
    as_root xbps-install -S 2>&1 || return 1
    # Packages the repository does not have (another architecture, musl) would stop the
    # whole transaction: leave them out
    xbps_dry "${rest[@]}"
    for p in "${TX_UNKNOWN[@]}"; do warn "Package $p is not in the repository, left out"; done
    (( ${#XBPS_OK[@]} )) || return 1
    say "installing: ${XBPS_OK[*]}"
    xbps_install "${XBPS_OK[@]}"
}

# ── Font ──────────────────────────────────────────────────────────────────────────

plan_font() {
    font_ok && return 1
    PLAN=("download JetBrainsMono Nerd Font $FONT_VERSION (7 MB, SHA-256 checked) into ${FONT_DIR/#$HOME/\~}")
}

run_font() {
    if font_ok; then say "$FONT_FAMILY is installed"; return 0; fi
    local tmp sum _ n
    tmp=$(mktemp -d) || return 1
    detail "downloading $FONT_VERSION"
    if ! curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 20 -o "$tmp/font.tar.xz" "$FONT_URL"; then
        rm -rf "$tmp"; return 1
    fi
    read -r sum _ < <(sha256sum "$tmp/font.tar.xz")
    if [[ $sum != "$FONT_SHA256" ]]; then
        say "SHA-256 does not match: $sum (expected $FONT_SHA256)"
        rm -rf "$tmp"; return 1
    fi
    detail "unpacking"
    mkdir -p "$tmp/x" "$FONT_DIR" || { rm -rf "$tmp"; return 1; }
    # the font with its full width icons ("Nerd Font"), not the Mono and Propo variants
    if ! tar -xJf "$tmp/font.tar.xz" -C "$tmp/x" --wildcards 'JetBrainsMonoNerdFont-*.ttf' OFL.txt; then
        rm -rf "$tmp"; return 1
    fi
    install -m644 "$tmp"/x/* "$FONT_DIR"/ || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
    detail "updating the font cache"
    fc-cache -f "$FONT_DIR" >/dev/null 2>&1
    n=("$FONT_DIR"/*.ttf)
    say "installed ${#n[@]} fonts into $FONT_DIR"
}

# ── Services ──────────────────────────────────────────────────────────────────────

# Services of the selection (or of module $1) that are not enabled yet -> SVC
services_todo() {
    local m s want=()
    for m in core bluetooth; do
        [[ -n ${1-} && $1 != "$m" ]] && continue
        [[ -z ${1-} ]] && ! (( ${SEL[$m]:-0} )) && continue
        case $m in
            core)      want+=(dbus elogind) ;;
            bluetooth) want+=(bluetoothd) ;;
        esac
    done
    SVC=()
    for s in "${want[@]}"; do
        service_on "$s" && continue
        # elogind started by D-Bus activation: a second one from runit would fail in a loop
        [[ $s == elogind ]] && pgrep -x elogind >/dev/null && continue
        SVC+=("$s")
    done
}

plan_services() {
    services_todo "${1-}"
    (( ${#SVC[@]} )) || return 1
    PLAN=("enable ${SVC[*]}")
}

run_services() {
    local s changed=0
    services_todo
    for s in "${SVC[@]}"; do
        if [[ ! -d $SV_DIR/$s ]]; then
            warn "Service $s is not installed ($SV_DIR/$s is missing)"
            continue
        fi
        as_root ln -s "$SV_DIR/$s" "$RUNSV_DIR/" || return 1
        say "enabled $s"
        changed=1
    done
    (( changed )) && need_reboot
    (( ${#SVC[@]} )) || say "every service is enabled"
    return 0
}

# ── Backlight (laptop) ────────────────────────────────────────────────────────────

BACKLIGHT_RULE=$SYSROOT/etc/udev/rules.d/90-backlight.rules

plan_backlight() {
    PLAN=()
    cmp -s "$DOTFILES/config/udev/90-backlight.rules" "$BACKLIGHT_RULE" ||
        PLAN+=("udev rule $BACKLIGHT_RULE: the group video may set the backlight")
    in_group video || PLAN+=("add $USER_NAME to the group video")
    (( ${#PLAN[@]} ))
}

run_backlight() {
    local src=$DOTFILES/config/udev/90-backlight.rules
    if ! cmp -s "$src" "$BACKLIGHT_RULE"; then
        as_root install -D -m644 "$src" "$BACKLIGHT_RULE" || return 1
        say "installed $BACKLIGHT_RULE"
        as_root udevadm control --reload-rules 2>&1
        as_root udevadm trigger --subsystem-match=backlight --action=add 2>&1
    fi
    if ! in_group video; then
        as_root usermod -aG video "$USER_NAME" || return 1
        say "added $USER_NAME to the group video"
        need_reboot
    fi
    return 0
}

# ── ALSA to PipeWire (audio) ──────────────────────────────────────────────────────

ALSA_CONFS=(50-pipewire.conf 99-pipewire-default.conf)

plan_alsa() {
    local f todo=0
    PLAN=()
    for f in "${ALSA_CONFS[@]}"; do
        [[ -e $SYSROOT/etc/alsa/conf.d/$f ]] || todo=1
    done
    (( todo )) && PLAN+=("link the PipeWire ALSA configs into /etc/alsa/conf.d")
    pipewire_dupes
    for f in "${PW_DUPES[@]}"; do
        PLAN+=("!$f also starts what i3 starts (wireplumber, pipewire-pulse): remove it")
    done
    (( todo ))
}

# Drop-ins from the Void handbook that make pipewire start wireplumber and pipewire-pulse itself;
# i3 starts both on its own, they would run twice
pipewire_dupes() {
    local f
    PW_DUPES=()
    for f in 10-wireplumber.conf 20-pipewire-pulse.conf; do
        [[ -e $SYSROOT/etc/pipewire/pipewire.conf.d/$f ]] && PW_DUPES+=("/etc/pipewire/pipewire.conf.d/$f")
    done
}

run_alsa() {
    local f src dir=$SYSROOT/etc/alsa/conf.d
    for f in "${ALSA_CONFS[@]}"; do
        src=/usr/share/alsa/alsa.conf.d/$f
        [[ -e $dir/$f || -L $dir/$f ]] && continue
        if [[ ! -e $src ]]; then warn "$src is missing (package alsa-pipewire)"; continue; fi
        as_root mkdir -p "$dir" || return 1
        as_root ln -s "$src" "$dir/$f" || return 1
        say "linked $dir/$f"
    done
    pipewire_dupes
    for f in "${PW_DUPES[@]}"; do
        warn "$f makes PipeWire start what i3 starts as well (wireplumber, pipewire-pulse): remove it"
    done
    return 0
}

# ── Login shell ───────────────────────────────────────────────────────────────────

plan_shell() {
    case $LOGIN_SHELL in
        */bash) return 1 ;;
        ""|/bin/sh|/usr/bin/sh|/bin/dash|/usr/bin/dash)
            PLAN=("login shell ${LOGIN_SHELL:-unknown} -> /bin/bash (prompt, vi mode, start of X)") ;;
        *)  PLAN=("!login shell is $LOGIN_SHELL: the prompt, vi mode and the start of X need bash")
            return 1 ;;
    esac
}

run_shell() {
    case $LOGIN_SHELL in
        */bash) say "the login shell is bash"; return 0 ;;
        ""|/bin/sh|/usr/bin/sh|/bin/dash|/usr/bin/dash) ;;
        *) warn "Your login shell is $LOGIN_SHELL: the prompt, vi mode and the start of X need bash (chsh -s /bin/bash)"
           return 0 ;;
    esac
    as_root usermod -s /bin/bash "$USER_NAME" || return 1
    say "login shell: /bin/bash"
    need_reboot
}

# ── Links ─────────────────────────────────────────────────────────────────────────

# The dry run is cached: it reads every link (a few hundred processes)
links_plan() {
    [[ -n ${LINKS_PLANNED-} ]] && return 0
    LINKS_DRY=1 links_run
    LINKS_PLANNED=1
    LINKS_PLAN_TODO=$LINKS_TODO
    LINKS_PLAN_BACKUPS=("${LINKS_BACKUPS[@]}")
}

plan_links() {
    local f
    links_plan
    (( LINKS_PLAN_TODO )) || return 1
    PLAN=("$LINKS_PLAN_TODO links into ~/.config, ~/.local/bin, ~/.local/share/applications")
    for f in "${LINKS_PLAN_BACKUPS[@]}"; do PLAN+=("keep ${f/#$HOME/\~} as *.bak-$STAMP"); done
}

run_links() {
    links_run
}

# ── Firefox ───────────────────────────────────────────────────────────────────────

FF_PREF='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

# The stylesheets are switched on: in user.js, or in prefs.js (about:config) and not off in user.js
ff_pref_on() {
    grep -qsF "$FF_PREF" "$FF_PROFILE/user.js" && return 0
    grep -qs 'legacyUserProfileCustomizations.stylesheets' "$FF_PROFILE/user.js" && return 1
    grep -qsF "$FF_PREF" "$FF_PROFILE/prefs.js"
}

plan_firefox() {
    local p
    PLAN=()
    if ! ff_profile; then
        PLAN=("create a profile (Firefox runs once, headless)" "link userChrome.css and userContent.css, enable them in user.js")
        return 0
    fi
    p=${FF_PROFILE/#$HOME/\~}
    [[ -L $FF_PROFILE/chrome/userChrome.css && -L $FF_PROFILE/chrome/userContent.css ]] ||
        PLAN+=("link userChrome.css and userContent.css into $p/chrome")
    ff_pref_on || PLAN+=("enable them in $p/user.js")
    (( ${#PLAN[@]} ))
}

run_firefox() {
    local tmp
    command -v firefox >/dev/null || { say "firefox is not installed"; return 1; }
    if ! ff_profile; then
        detail "creating a profile"
        tmp=$(mktemp -d) || return 1
        # a headless screenshot creates the profile the normal way (installs.ini) and quits
        timeout 120 firefox --headless --no-remote --screenshot "$tmp/shot.png" about:blank >/dev/null 2>&1
        rm -rf "$tmp"
        ff_profile || { say "Firefox did not create a profile"; return 1; }
        say "created the profile $FF_PROFILE"
    fi
    link "$DOTFILES/firefox/userChrome.css" "$FF_PROFILE/chrome/userChrome.css" || return 1
    link "$DOTFILES/firefox/userContent.css" "$FF_PROFILE/chrome/userContent.css" || return 1
    if ! ff_pref_on; then
        printf '%s\n' "$FF_PREF" >> "$FF_PROFILE/user.js" || return 1
        say "user.js: $FF_PREF"
    fi
    pgrep -x firefox >/dev/null && note "Firefox: restart it for the new look."
    return 0
}

# ── neomutt ───────────────────────────────────────────────────────────────────────

MUTT_LINES=("source ~/.config/mutt/notify.muttrc" "source ~/.config/mutt/theme.muttrc")

# The file neomutt reads -> MUTTRC (empty: none yet)
muttrc_find() {
    local f
    MUTTRC=""
    for f in "$HOME/.neomuttrc" "$CONFIG/neomutt/neomuttrc" "$HOME/.muttrc" "$CONFIG/mutt/muttrc"; do
        [[ -f $f ]] && { MUTTRC=$f; return 0; }
    done
    return 1
}

plan_mail() {
    local l n=0
    if ! muttrc_find; then PLAN=("create ~/.muttrc with the two source lines (accounts go above them)"); return 0; fi
    for l in "${MUTT_LINES[@]}"; do grep -qsF "$l" "$MUTTRC" || (( n++ )); done
    (( n )) || return 1
    PLAN=("add $n source lines to ${MUTTRC/#$HOME/\~} (theme and new-mail notifications)")
}

run_mail() {
    local l add=()
    if ! muttrc_find; then
        MUTTRC=$HOME/.muttrc
        printf '%s\n' "# neomutt: put your account settings here, above the source lines (the theme comes last)" \
            > "$MUTTRC" || return 1
        say "created $MUTTRC"
    fi
    for l in "${MUTT_LINES[@]}"; do grep -qsF "$l" "$MUTTRC" || add+=("$l"); done
    (( ${#add[@]} )) || { say "$MUTTRC sources the theme already"; return 0; }
    { printf '\n# dotfiles (install.sh): new-mail notifications, colors and formats\n'
      printf '%s\n' "${add[@]}"; } >> "$MUTTRC" || return 1
    say "added to $MUTTRC: ${add[*]}"
}

# ── Theme ─────────────────────────────────────────────────────────────────────────

plan_theme() {
    PLAN=("generate ~/.config/dotfiles from dotfiles.conf, draw the cursor theme into ~/.icons/dotfiles")
    wallpaper_path
    [[ -e $WALLPAPER ]] || PLAN+=("plain wallpaper in the background color at ${WALLPAPER/#$HOME/\~} (replace it with yours)")
    return 0
}

# The wallpaper from dotfiles.conf -> WALLPAPER
wallpaper_path() {
    local k v
    WALLPAPER=$HOME/images/wallpaper
    while IFS='=' read -r k v; do
        k=${k//[[:space:]]/}
        [[ $k == wallpaper ]] || continue
        v=${v#"${v%%[![:space:]]*}"}; v=${v%"${v##*[![:space:]]}"}
        [[ -n $v ]] && WALLPAPER=${v/#\~/$HOME}
    done < "$DOTFILES/dotfiles.conf"
}

run_theme() {
    local bg='#191c1c'
    command -v python3 >/dev/null || { say "python3 is not installed (core packages)"; return 1; }
    mkdir -p "$HOME/images/screenshots"
    detail "dotfiles apply"
    "$DOTFILES/scripts/dotfiles" apply --no-reload || return 1
    wallpaper_path
    if [[ ! -e $WALLPAPER ]]; then
        bg=$(. "$CONFIG/dotfiles/theme.sh" 2>/dev/null; printf '%s' "${DF_BG:-#191c1c}")
        mkdir -p "$(dirname "$WALLPAPER")" &&
            python3 - "$WALLPAPER" "$bg" <<'EOF' || return 1
# a PNG in one color (feh stretches it over the screen)
import struct, sys, zlib
path, rgb = sys.argv[1], bytes.fromhex(sys.argv[2].lstrip("#"))
w = h = 64
raw = b"".join(b"\0" + rgb * w for _ in range(h))
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
with open(path, "wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
EOF
        say "wallpaper placeholder: $WALLPAPER"
        note "Wallpaper: ${WALLPAPER/#$HOME/\~} is a plain placeholder, put your own picture there."
    fi
}

# ── Neovim plugins ────────────────────────────────────────────────────────────────

plan_nvim() {
    PLAN=("install the plugins at the versions of lazy-lock.json (needs network, a few minutes)")
    return 0
}

run_nvim() {
    local lock=$CONFIG/nvim/lazy-lock.json saved rc
    command -v nvim >/dev/null || { say "nvim is not installed"; return 1; }
    command -v git >/dev/null || { say "git is not installed"; return 1; }
    saved=$(mktemp) || return 1
    cp "$lock" "$saved" 2>/dev/null
    # 1. LazyVim installs what is missing. lazy.nvim then writes the commits it got into
    #    lazy-lock.json (a link into this repository): put the file back afterwards.
    detail "installing the plugins (lazy.nvim)"
    nvim_headless "+Lazy! install"
    rc=$?
    [[ -s $saved ]] && ! cmp -s "$saved" "$lock" && cat "$saved" > "$lock"
    # 2. Every plugin to its commit in lazy-lock.json
    if (( rc == 0 )); then
        detail "checking out the versions of lazy-lock.json"
        nvim_headless "+Lazy! restore"
        rc=$?
    fi
    if [[ -s $saved ]] && ! cmp -s "$saved" "$lock"; then
        cat "$saved" > "$lock"
        say "lazy-lock.json put back to the version of the repository"
    fi
    rm -f "$saved"
    (( rc == 0 )) || return "$rc"
    note "Neovim: language servers and Treesitter parsers install themselves on the first start."
}

# nvim --headless CMD +qa, its git progress left out of the log
nvim_headless() {
    timeout 1800 nvim --headless "$1" +qa 2>&1 | tr '\r' '\n' |
        sed -u -e 's/\x1b\[[0-9;]*m//g' -e '/Receiving objects\|Resolving deltas\|Counting objects\|Compressing objects\|Enumerating objects/d' |
        grep -v '^[[:space:]]*$'
    return "${PIPESTATUS[0]}"
}

# ── Start X on login ──────────────────────────────────────────────────────────────

AUTOSTART_MARK="# dotfiles: start X on tty1"

plan_autostart() {
    grep -qsF "$AUTOSTART_MARK" "$HOME/.bash_profile" && return 1
    PLAN=("~/.bash_profile: logging in on tty1 runs startx")
    [[ -n $DM ]] && PLAN+=("!the display manager $DM is enabled: it does not read ~/.xinitrc")
    return 0
}

run_autostart() {
    local f=$HOME/.bash_profile
    if grep -qsF "$AUTOSTART_MARK" "$f"; then say "~/.bash_profile starts X already"; return 0; fi
    if [[ ! -e $f ]]; then
        # bash reads ~/.profile only when there is no ~/.bash_profile: keep it working
        printf '%s\n' "# ~/.bash_profile: login shells" \
            '[ -f ~/.profile ] && . ~/.profile' '[ -f ~/.bashrc ] && . ~/.bashrc' > "$f" || return 1
    fi
    cat >> "$f" <<EOF || return 1

$AUTOSTART_MARK (install.sh). exec: logging out of i3 ends the login, and no
# shell stays logged in on tty1 if X stops.
if [ -z "\${DISPLAY:-}" ] && [ "\$(tty)" = /dev/tty1 ] && command -v startx >/dev/null; then
    exec startx
fi
EOF
    say "~/.bash_profile starts X after logging in on tty1"
    [[ -n $DM ]] && warn "The display manager $DM is enabled: it starts its own session, not ~/.xinitrc."
    return 0
}

# ── NetworkManager (last: the connection drops for a moment) ──────────────────────

plan_network() {
    detect_net
    PLAN=()
    (( NM_ON && ${#NET_OLD[@]} == 0 )) && return 1
    (( NM_ON )) || PLAN+=("enable NetworkManager")
    (( ${#NET_OLD[@]} )) && PLAN+=("disable ${NET_OLD[*]} (last step: the connection drops for a few seconds)")
    (( ${#WPA_CONFS[@]} )) && PLAN+=("copy the WiFi networks of wpa_supplicant to NetworkManager (keys stay root-only)")
    [[ " ${NET_OLD[*]} " == *" iwd "* ]] && PLAN+=("!networks saved by iwd are not copied: choose them again in the WiFi menu")
    return 0
}

run_network() {
    local s kind ssid reason state i
    [[ -d $SV_DIR/NetworkManager ]] || { say "NetworkManager is not installed"; return 1; }
    detect_net
    if (( NM_ON && ${#NET_OLD[@]} == 0 )); then say "NetworkManager is active"; return 0; fi
    if (( ${#WPA_CONFS[@]} )); then
        detail "copying the WiFi networks"
        while IFS=$'\t' read -r kind ssid reason; do
            case $kind in
                migrated) say "WiFi network copied: $ssid"; note "WiFi: \"$ssid\" moved to NetworkManager." ;;
                skipped)  say "WiFi network not copied: $ssid ($reason)"; warn "WiFi: \"$ssid\" not copied: $reason." ;;
                *)        say "$kind${ssid:+ $ssid}${reason:+ $reason}" ;;
            esac
        done < <(as_root python3 "$DOTFILES/install/nm-migrate" --root "${SYSROOT:-/}" 2>&1)
    fi
    for s in "${NET_OLD[@]}"; do
        detail "stopping $s"
        as_root sv down "$RUNSV_DIR/$s" >/dev/null 2>&1
        as_root rm "$RUNSV_DIR/$s" || return 1
        say "disabled $s"
    done
    if (( ! NM_ON )); then
        # dhcpcd's hook starts its own wpa_supplicant; NetworkManager starts one over D-Bus
        as_root pkill -x wpa_supplicant >/dev/null 2>&1
        as_root ln -s "$SV_DIR/NetworkManager" "$RUNSV_DIR/" || return 1
        say "enabled NetworkManager"
    fi
    detail "waiting for a connection"
    for (( i = 0; i < 40; i++ )); do
        state=$(nmcli -t -f STATE general 2>/dev/null)
        [[ $state == connected* ]] && break
        sleep 1
    done
    case $state in
        "connected")  say "NetworkManager is connected" ;;
        connected*)   say "NetworkManager: $state" ;;
        *) note "NetworkManager is not connected yet: pick a network in the WiFi menu (click the WiFi capsule)." ;;
    esac
    return 0
}
