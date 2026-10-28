# shellcheck shell=bash
# install/modules.sh  ·  what the installer can set up, in parts ("modules"), and the plan for
# a selection of them. Every module has packages and steps (install/steps.sh).

MODULES=(core system graphics audio network bluetooth laptop neovim firefox mail music tools autostart)

declare -A M_TITLE M_DESC M_PKGS M_STEPS M_REQ M_OFF M_MISSING M_WORK SEL

M_TITLE[core]="Desktop"
M_REQ[core]=1
M_DESC[core]="The desktop itself: i3, Polybar, Rofi, Dunst, picom, Alacritty, the lock screen and the \
screensaver, the shell (bash, fzf, tmux), the GTK theme, the mouse cursor and the JetBrainsMono Nerd \
Font. Links every file of this repository into place and generates the theme from dotfiles.conf."
M_PKGS[core]="xorg-minimal xinit xauth xrdb xsetroot xset xrandr setxkbmap
 i3 picom polybar rofi dunst libnotify alacritty feh xclip xbanish scrot
 xss-lock i3lock-color libXScrnSaver dbus elogind polkit polkit-gnome
 python3 python3-gobject python3-cairo python3-numpy gtk+3 adwaita-icon-theme
 fontconfig dejavu-fonts-ttf desktop-file-utils git curl xz fzf tmux ncurses bash"
M_STEPS[core]="font services shell links theme"

M_TITLE[system]="System update"
M_DESC[system]="Updates xbps and every installed package before anything new is installed. Void is a \
rolling release: new packages are built against the current repository, installing them into an \
old system is what breaks."
M_STEPS[system]="update"

M_TITLE[graphics]="Graphics drivers"
M_DESC[graphics]="Mesa for the GPUs of this machine: OpenGL (Alacritty and picom need it), Vulkan and \
video decoding. mesa-dri covers Intel, AMD, nouveau and virtual machines; only the Vulkan and VA-API \
drivers depend on the vendor. With per-monitor scaling (scale = auto) a software mouse pointer, so it \
has the same size on every monitor."
M_STEPS[graphics]="swcursor"

M_TITLE[audio]="Audio"
M_DESC[audio]="PipeWire with WirePlumber and its PulseAudio server (i3 starts all three), ALSA \
programs routed through PipeWire, pulsemixer. The volume keys and capsule and the music \
screensaver need it."
M_PKGS[audio]="pipewire wireplumber alsa-pipewire pulseaudio-utils pulsemixer"
M_STEPS[audio]="alsa"

M_TITLE[network]="Network"
M_DESC[network]="NetworkManager with the OpenVPN and Cisco/FRITZ!Box plugins and nm-connection-editor: \
the WiFi, IP and VPN capsules and menus need it. As the very last step it replaces dhcpcd and \
wpa_supplicant and takes over their WiFi networks."
M_PKGS[network]="NetworkManager libnm NetworkManager-openvpn NetworkManager-vpnc network-manager-applet"
M_STEPS[network]="network"

M_TITLE[bluetooth]="Bluetooth"
M_DESC[bluetooth]="BlueZ and the PipeWire Bluetooth plugin (headphones): the Bluetooth capsule, its \
menu and Super+b."
M_PKGS[bluetooth]="bluez libspa-bluetooth"
M_STEPS[bluetooth]="services"

M_TITLE[laptop]="Laptop"
M_DESC[laptop]="Brightness keys and capsule: brightnessctl, a udev rule that lets the group video set \
the backlight, and your user in that group."
M_PKGS[laptop]="brightnessctl"
M_STEPS[laptop]="backlight"

M_TITLE[neovim]="Neovim"
M_DESC[neovim]="Neovim with LazyVim and what it builds and runs with: git, gcc, make, tree-sitter, \
ripgrep, fd, Node.js (language servers), OpenJDK 21 (Java and Kotlin). Installs the plugins at the \
versions of lazy-lock.json."
M_PKGS[neovim]="neovim git gcc make tree-sitter-cli ripgrep fd curl unzip nodejs openjdk21"
M_STEPS[neovim]="nvim"

M_TITLE[firefox]="Firefox"
M_DESC[firefox]="Firefox in the desktop look: links userChrome.css and userContent.css into your \
profile (creates one if there is none) and switches them on."
M_PKGS[firefox]="firefox noto-fonts-emoji"
M_STEPS[firefox]="firefox"

M_TITLE[mail]="Mail"
M_DESC[mail]="neomutt with the theme and new-mail notifications: adds two source lines to your \
muttrc (creates ~/.muttrc if you have none). Your accounts stay yours."
M_PKGS[mail]="neomutt"
M_STEPS[mail]="mail"

M_TITLE[music]="Music"
M_DESC[music]="mpv and mpvim, the terminal player with album covers (chafa, Pillow, ffmpeg), and \
playerctl for the music capsule. Links the mpv-mpris plugin into ~/.config/mpv/scripts (Void \
installs it where mpv does not look), so the capsule shows what mpv plays."
M_PKGS[music]="mpv mpv-mpris playerctl ffmpeg chafa python3-Pillow"
M_STEPS[music]="mpris"

M_TITLE[tools]="Tools"
M_DESC[tools]="htop (in Rofi as a floating window) and xdg-utils (opens files and links with the \
right program)."
M_PKGS[tools]="htop xdg-utils"

M_TITLE[autostart]="Start X on login"
M_DESC[autostart]="Logging in on tty1 starts the desktop (startx from ~/.bash_profile), logging out \
of i3 ends the login again. Not for a display manager: it does not read ~/.xinitrc."
M_STEPS[autostart]="autostart"

# Packages of module $1 -> MP
mod_pkgs() {
    MP=()
    if [[ $1 == graphics ]]; then
        MP=(mesa-dri)
        (( GPU_INTEL ))  && MP+=(vulkan-loader mesa-vulkan-intel intel-video-accel)
        (( GPU_AMD ))    && MP+=(vulkan-loader mesa-vulkan-radeon mesa-vaapi)
        if (( GPU_NVIDIA )); then
            case ${NVIDIA_DRIVER:-nouveau} in
                nouveau) MP+=(vulkan-loader mesa-vulkan-nouveau) ;;
                *)       MP+=(void-repo-nonfree linux-headers "$NVIDIA_DRIVER") ;;
            esac
        fi
        return
    fi
    # shellcheck disable=SC2206
    local -; set -f
    MP=(${M_PKGS[$1]-})
}

nvidia_label() {
    case $1 in
        nouveau)   _NL="nouveau: open source, every GeForce" ;;
        nvidia)    _NL="nvidia: GTX 16xx, RTX 20xx and newer" ;;
        nvidia580) _NL="nvidia580: GTX 750 to GTX 10xx, Titan V" ;;
        nvidia470) _NL="nvidia470: Kepler, GTX 600 and 700" ;;
    esac
}

# Defaults: everything, except what this machine has no use for
mods_default() {
    local m
    for m in "${MODULES[@]}"; do SEL[$m]=1; M_OFF[$m]=""; done
    [[ -z $BT_ADAPTER ]] && { SEL[bluetooth]=0; M_OFF[bluetooth]="no adapter"; }
    [[ -z $BACKLIGHT ]]  && { SEL[laptop]=0;    M_OFF[laptop]="no backlight"; }
    [[ -n $DM ]]         && { SEL[autostart]=0; M_OFF[autostart]="uses $DM"; }
    if [[ -z $NVIDIA_DRIVER ]]; then
        NVIDIA_DRIVER=nouveau
        local d
        for d in "${NVIDIA_DRIVERS[@]:1}"; do pkg_have "$d" && NVIDIA_DRIVER=$d; done
    fi
}

# Per module: missing packages and whether a step has something to do (for the module list)
mods_scan() {
    local m p n st
    for m in "${MODULES[@]}"; do
        mod_pkgs "$m"
        n=0
        (( HAVE_XBPS )) && for p in "${MP[@]}"; do pkg_have "$p" || (( n++ )); done
        M_MISSING[$m]=$n
        M_WORK[$m]=0
        for st in ${M_STEPS[$m]-}; do
            if plan_step "$st" "$m"; then M_WORK[$m]=1; break; fi
        done
    done
}

# ── The plan of the selection ─────────────────────────────────────────────────────

# Packages of the selected modules -> SP (all), SM (missing), in module order
sel_pkgs() {
    local m p
    local -A seen=()
    SP=() SM=()
    (( HAVE_XBPS )) || return 0
    for m in "${MODULES[@]}"; do
        (( ${SEL[$m]:-0} )) || continue
        mod_pkgs "$m"
        for p in "${MP[@]}"; do
            [[ -n ${seen[$p]-} ]] && continue
            seen[$p]=1
            SP+=("$p")
            pkg_have "$p" || SM+=("$p")
        done
    done
}

# Steps of the selection, in the order they run -> SS
sel_steps() {
    local st m
    SS=()
    for st in "${STEP_ORDER[@]}"; do
        if [[ $st == packages ]]; then
            (( HAVE_XBPS && ${#SM[@]} )) && SS+=(packages)
            continue
        fi
        for m in "${MODULES[@]}"; do
            (( ${SEL[$m]:-0} )) || continue
            [[ " ${M_STEPS[$m]-} " == *" $st "* ]] && { SS+=("$st"); break; }
        done
    done
    # without xbps (not Void) only the steps in the home directory are possible
    if (( ! HAVE_XBPS )); then
        local keep=()
        for st in "${SS[@]}"; do (( ${STEP_ROOT[$st]:-0} )) || keep+=("$st"); done
        SS=("${keep[@]}")
    fi
}

# True if one of the steps in SS needs root
sel_needs_root() {
    local st
    for st in "${SS[@]}"; do (( ${STEP_ROOT[$st]:-0} )) && return 0; done
    return 1
}
