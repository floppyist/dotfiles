# shellcheck shell=bash
# install/modules.sh  ·  what the installer can set up, in parts ("modules"), and the plan for
# a selection of them. Every module has packages and steps (install/steps.sh).

MODULES=(core system graphics audio network bluetooth laptop neovim firefox mail music tools dualboot fixes kernel autostart)

declare -A M_TITLE M_DESC M_PKGS M_STEPS M_REQ M_OFF M_MISSING M_WORK SEL

M_TITLE[core]="Desktop"
M_REQ[core]=1
M_DESC[core]="The desktop itself: i3, Polybar, Rofi, Dunst, picom, Alacritty, the lock screen and the \
screensaver, the shell (bash, fzf, tmux), the GTK theme, the mouse cursor and the JetBrainsMono Nerd \
Font. Links every file of this repository into place and generates the theme from dotfiles.conf \
(mouse and touchpad settings are in there too). What the distribution does not have in a recent \
enough version (the lock screen, fzf, ...) comes from its project, version and checksum pinned."
M_PKGS[core]="xorg-minimal xinit xauth xrdb xsetroot xset xrandr setxkbmap xinput
 i3 picom polybar rofi dunst libnotify alacritty feh xclip xbanish scrot
 xss-lock i3lock-color libXScrnSaver dbus elogind polkit polkit-gnome
 python3 python3-gobject python3-cairo python3-numpy gtk+3 adwaita-icon-theme
 fontconfig dejavu-fonts-ttf desktop-file-utils git curl xz fzf tmux ncurses bash"
M_STEPS[core]="upstream font services pointer shell links theme"

M_TITLE[system]="System update"
M_DESC[system]="Updates the package manager and every installed package before anything new is \
installed: new packages are built against the current repository, installing them into an old \
system is what breaks (on rolling releases like Void and Arch)."
M_STEPS[system]="update"

M_TITLE[graphics]="Graphics drivers"
M_DESC[graphics]="Mesa for the GPUs of this machine: OpenGL (Alacritty and picom need it), Vulkan and \
video decoding. mesa-dri covers Intel, AMD, nouveau and virtual machines; only the Vulkan and VA-API \
drivers depend on the vendor. AMD also gets its Xorg driver (xf86-video-amdgpu, xf86-video-ati for old \
cards): with its TearFree a window has the same size on monitors of different sharpness, without \
tearing."
M_STEPS[graphics]="swcursor"

M_TITLE[audio]="Audio"
M_DESC[audio]="PipeWire with WirePlumber and its PulseAudio server (started with the session \
unless the system does it), ALSA programs routed through PipeWire, pulsemixer. The volume keys and capsule and the music \
screensaver need it."
M_PKGS[audio]="pipewire wireplumber alsa-pipewire pulseaudio-utils pulsemixer"
M_STEPS[audio]="alsa"

M_TITLE[network]="Network"
M_DESC[network]="NetworkManager with the OpenVPN and Cisco/FRITZ!Box plugins and nm-connection-editor: \
the WiFi, IP and VPN capsules and menus need it. As the very last step it is switched on. On Void it \
replaces dhcpcd and wpa_supplicant and takes over their WiFi networks; elsewhere only when no other \
service manages the network (otherwise you get a note what to switch off)."
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
playerctl for the music capsule. On Void it links the mpv-mpris plugin into ~/.config/mpv/scripts \
(Void installs it where mpv does not look), so the capsule shows what mpv plays."
M_PKGS[music]="mpv mpv-mpris playerctl ffmpeg chafa python3-Pillow"
M_STEPS[music]="mpris"

M_TITLE[tools]="Tools"
M_DESC[tools]="htop (in Rofi as a floating window) and xdg-utils (opens files and links with the \
right program)."
M_PKGS[tools]="htop xdg-utils"

M_TITLE[dualboot]="Dual boot"
M_DESC[dualboot]="Experimental. Windows or another Linux next to this system: os-prober looks at the other disks \
and GRUB lists what it finds in the boot menu (GRUB switches this off by default). Afterwards the \
installer checks that every system the firmware knows is in the menu, and tells you what to do when one \
is missing: Windows Fast Startup, the clock, the boot order. You can also have a second system set up: \
choose Arch, Debian, Ubuntu, Fedora, Alpine or Windows in the next screen. The installer makes a \
partition from unallocated space (nothing is shrunk or deleted), downloads the ISO (signed by the \
distribution, checked against its pinned key; Windows: your ISO) and adds a boot entry; the rest of the space stays free for \
that system's own installer. Only for GRUB; systemd-boot lists \
Windows by itself when it is on the same EFI partition."
M_STEPS[dualboot]="dualboot othersys"

M_TITLE[fixes]="Hardware fixes"
M_DESC[fixes]="Settings for special hardware that would otherwise be a problem, like a kernel parameter \
for one model. Nothing here is on unless this machine needs it; you choose which ones in the next \
screen of the installation. Kernel parameters go into GRUB_CMDLINE_LINUX_DEFAULT."
M_STEPS[fixes]="fixes"

M_TITLE[kernel]="Custom kernel"
M_DESC[kernel]="Experimental. kernelforge: a Linux kernel for this machine only. Takes the configuration of the \
running kernel, keeps the modules that are loaded now, builds it from the signed source of kernel.org \
(you choose the version) and installs it next to the running one: modules, initramfs, boot entry. \
Nothing that is installed gets replaced. It becomes the default entry of the boot menu (the others stay). \
Takes 10 to 40 minutes and needs about 8 GB; not part of the complete installation. Plug in the devices you use first: a module that is not loaded is left out. Void Linux only."
M_PKGS[kernel]="base-devel flex bison bc openssl-devel elfutils-devel zlib-devel pahole perl cpio kmod gnupg xz curl python3 dracut"
M_STEPS[kernel]="kernel"

M_TITLE[autostart]="Start X on login"
M_DESC[autostart]="Logging in on tty1 starts the desktop (startx from ~/.bash_profile), logging out \
of i3 ends the login again. Not for a display manager: it does not read ~/.xinitrc."
M_STEPS[autostart]="autostart"

# ── Hardware fixes ────────────────────────────────────────────────────────────────
# One entry per fix: FIX_TITLE, FIX_DESC, FIX_PARAM (kernel parameter) and fix_match_<id>
# (true if this machine needs it). New fixes are added here.

FIXES=(amdgpu-dpm)
declare -A FIX_TITLE FIX_DESC FIX_PARAM FIX_WHO FIX_SEL

FIX_TITLE[amdgpu-dpm]="amdgpu.dpm=0"
FIX_PARAM[amdgpu-dpm]="amdgpu.dpm=0"
FIX_WHO[amdgpu-dpm]="iMac 27-inch late 2015 (iMac17,1) with AMD graphics"
FIX_DESC[amdgpu-dpm]="Switches the power management of the AMD GPU off. On the iMac late 2015 the \
amdgpu driver otherwise waits for it for a long time: booting and rebooting takes forever. Costs a \
little idle power and the GPU clocks stay fixed."
fix_match_amdgpu-dpm() {
    # the 21.5-inch models of late 2015 (iMac16,x) have Intel graphics only
    [[ $DMI_VENDOR == Apple* && $DMI_PRODUCT == iMac17,1 ]] && (( GPU_AMDGPU ))
}

fixes_matching() {
    local f
    FX_MATCH=()
    for f in "${FIXES[@]}"; do "fix_match_$f" && FX_MATCH+=("$f"); done
}

# The chosen fixes -> FIXC
fixes_chosen() {
    local f
    FIXC=()
    for f in "${FIXES[@]}"; do (( ${FIX_SEL[$f]:-0} )) && FIXC+=("$f"); done
}

# Packages of module $1 -> MP
mod_pkgs() {
    MP=()
    if [[ $1 == dualboot ]]; then
        [[ $BOOTLOADER == grub ]] && MP=(os-prober ntfs-3g)
        [[ $DUAL_TARGET == windows ]] && MP+=(dosfstools wimlib)
        [[ -n $DUAL_TARGET && $DUAL_TARGET != windows ]] && MP+=(gnupg)
        return
    fi
    if [[ $1 == graphics ]]; then
        MP=(mesa-dri)
        (( GPU_INTEL ))  && MP+=(vulkan-loader mesa-vulkan-intel intel-video-accel)
        (( GPU_AMD ))    && MP+=(vulkan-loader mesa-vulkan-radeon mesa-vaapi)
        # the Xorg driver of the kernel driver in use (TearFree; modesetting has none)
        (( GPU_AMDGPU )) && MP+=(xf86-video-amdgpu)
        (( GPU_RADEON )) && MP+=(xf86-video-ati)
        if (( GPU_NVIDIA )); then
            [[ $DISTRO == void ]] || NVIDIA_DRIVER=nouveau
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
    # tools Void has in its base system (procps, util-linux, ...)
    [[ $1 == core && -n $DISTRO && $DISTRO != void ]] && MP+=(base-tools)
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
    local m keep=()
    # the custom kernel builds and boots with Void's tools (dracut, xbps paths)
    if [[ $DISTRO != void ]]; then
        for m in "${MODULES[@]}"; do [[ $m == kernel ]] || keep+=("$m"); done
        MODULES=("${keep[@]}")
    fi
    for m in "${MODULES[@]}"; do SEL[$m]=1; M_OFF[$m]=""; done
    [[ -z $BT_ADAPTER ]] && { SEL[bluetooth]=0; M_OFF[bluetooth]="no adapter"; }
    [[ -z $BACKLIGHT ]]  && { SEL[laptop]=0;    M_OFF[laptop]="no backlight"; }
    [[ -n $DM ]]         && { SEL[autostart]=0; M_OFF[autostart]="uses $DM"; }
    # a long build: only when asked for (also not in `all`)
    SEL[kernel]=0; M_OFF[kernel]="optional"
    DUAL_TARGET="" DUAL_DISK="" WIN_ISO=""
    (( ${#OTHER_OS[@]} )) || { SEL[dualboot]=0; M_OFF[dualboot]="no other system found"; }
    local f
    fixes_matching
    for f in "${FIXES[@]}"; do FIX_SEL[$f]=0; done
    for f in "${FX_MATCH[@]}"; do FIX_SEL[$f]=1; done
    (( ${#FX_MATCH[@]} )) || { SEL[fixes]=0; M_OFF[fixes]="none needed here"; }
    if [[ -z $NVIDIA_DRIVER ]]; then
        NVIDIA_DRIVER=nouveau
        local d
        for d in "${NVIDIA_DRIVERS[@]:1}"; do pkg_have "$d" && NVIDIA_DRIVER=$d; done
    fi
}

# Per module: missing packages and whether a step has something to do (for the module list)
mods_scan() {
    local m p q n st
    for m in "${MODULES[@]}"; do
        mod_pkgs "$m"
        n=0
        if (( HAVE_PM )); then
            for p in "${MP[@]}"; do
                pkg_map "$p"
                for q in "${_PM[@]}"; do
                    case $q in
                        @*) up_have "${q#@*:}" || (( n++ )) ;;
                        *)  pkg_have "$q" || (( n++ )) ;;
                    esac
                done
            done
        fi
        M_MISSING[$m]=$n
        M_WORK[$m]=0
        for st in ${M_STEPS[$m]-}; do
            if plan_step "$st" "$m"; then M_WORK[$m]=1; break; fi
        done
    done
}

# ── The plan of the selection ─────────────────────────────────────────────────────

# Packages of the selected modules, with this distribution's names -> SP (all), SM (missing, with
# the build dependencies of SU), SU (upstream programs: install/upstream.sh), in module order
sel_pkgs() {
    local m p q
    local -A seen=()
    SP=() SM=() SU=()
    (( HAVE_PM )) || return 0
    for m in "${MODULES[@]}"; do
        (( ${SEL[$m]:-0} )) || continue
        # the kernel module builds with Void's tools only
        [[ $m == kernel && $DISTRO != void ]] && continue
        mod_pkgs "$m"
        for p in "${MP[@]}"; do
            pkg_map "$p"
            for q in "${_PM[@]}"; do
                [[ -n ${seen[$q]-} ]] && continue
                seen[$q]=1
                if [[ $q == @* ]]; then SU+=("${q#@*:}"); continue; fi
                SP+=("$q")
                pkg_have "$q" || SM+=("$q")
            done
        done
    done
    up_deps "${SU[@]}"
    for q in "${_UD[@]}"; do
        [[ -n ${seen[$q]-} ]] && continue
        seen[$q]=1
        SM+=("$q")
    done
}

# Steps of the selection, in the order they run -> SS
sel_steps() {
    local st m
    SS=()
    for st in "${STEP_ORDER[@]}"; do
        if [[ $st == packages ]]; then
            (( HAVE_PM )) && { (( ${#SM[@]} )) || apk_community_off; } && SS+=(packages)
            continue
        fi
        if [[ $st == upstream ]]; then
            (( HAVE_PM )) && plan_step upstream && SS+=(upstream)
            continue
        fi
        [[ $st == othersys && -z $DUAL_TARGET ]] && continue
        for m in "${MODULES[@]}"; do
            (( ${SEL[$m]:-0} )) || continue
            [[ " ${M_STEPS[$m]-} " == *" $st "* ]] && { SS+=("$st"); break; }
        done
    done
    # without a known package manager only the steps in the home directory are possible
    if (( ! HAVE_PM )); then
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
