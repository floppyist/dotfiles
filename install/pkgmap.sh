# shellcheck shell=bash
# install/pkgmap.sh  ·  package names per distribution. The modules (modules.sh) list Void's names;
# this table turns each into the names of the other distributions.
#
#   =          the same name
#   -          nothing to install there (part of the base system, or another package has it)
#   ~          (ubuntu) the same as debian
#   @src:NAME  not packaged (or too old): built from a pinned upstream source (install/upstream.sh)
#   @bin:NAME  too old: the pinned upstream release binary into ~/.local (install/upstream.sh)
#   a b c      several packages (no comments inside the table)
#   Alpine: polkit comes as polkit-elogind (with elogind)
#
# Checked against the repositories of Arch, Debian 13, Ubuntu 26.04, Fedora 45 and Alpine 3.24 (2026-11).
# Debian 13 is too old for fzf (0.60: --gutter needs 0.66), Neovim (0.10: LazyVim needs 0.11.2)
# and tree-sitter (0.22: nvim-treesitter needs 0.25).

PKGMAP_TABLE='
# void                    | arch                       | debian                         | ubuntu | fedora                              | alpine
xorg-minimal              | xorg-server xf86-input-libinput | xserver-xorg-core xserver-xorg-input-libinput | ~ | xorg-x11-server-Xorg xorg-x11-drv-libinput | xorg-server xf86-input-libinput eudev eudev-openrc
xinit                     | xorg-xinit                 | xinit                          | ~      | xorg-x11-xinit                      | xinit
xauth                     | xorg-xauth                 | xauth                          | ~      | xorg-x11-xauth                      | =
xrdb                      | xorg-xrdb                  | x11-xserver-utils              | ~      | =                                   | =
xsetroot                  | xorg-xsetroot              | x11-xserver-utils              | ~      | =                                   | =
xset                      | xorg-xset                  | x11-xserver-utils              | ~      | =                                   | =
xrandr                    | xorg-xrandr                | x11-xserver-utils              | ~      | =                                   | =
setxkbmap                 | xorg-setxkbmap             | x11-xkb-utils                  | ~      | =                                   | =
xinput                    | xorg-xinput                | =                              | ~      | =                                   | =
i3                        | i3-wm                      | i3-wm                          | ~      | =                                   | i3wm
picom                     | =                          | =                              | ~      | =                                   | =
polybar                   | =                          | =                              | ~      | =                                   | =
rofi                      | =                          | =                              | ~      | =                                   | =
dunst                     | =                          | =                              | ~      | =                                   | =
libnotify                 | =                          | libnotify-bin                  | ~      | =                                   | =
alacritty                 | =                          | =                              | ~      | =                                   | =
feh                       | =                          | =                              | ~      | =                                   | =
xclip                     | =                          | =                              | ~      | =                                   | =
xbanish                   | @src:xbanish               | =                              | ~      | =                                   | =
scrot                     | =                          | =                              | ~      | =                                   | =
xss-lock                  | =                          | =                              | ~      | =                                   | @src:xss-lock
i3lock-color              | @src:i3lock-color          | @src:i3lock-color              | ~      | @src:i3lock-color                   | =
libXScrnSaver             | libxss                     | libxss1                        | ~      | =                                   | libxscrnsaver
dbus                      | =                          | dbus dbus-user-session         | ~      | =                                   | dbus dbus-x11 dbus-openrc
elogind                   | -                          | -                              | ~      | -                                   | elogind elogind-openrc polkit-elogind
polkit                    | =                          | polkitd                        | ~      | =                                   | -
polkit-gnome              | =                          | mate-polkit                    | policykit-1-gnome | mate-polkit                  | =
python3                   | python                     | =                              | ~      | =                                   | =
python3-gobject           | python-gobject             | python3-gi python3-gi-cairo gir1.2-gtk-3.0 | ~ | python3-gobject gtk3           | py3-gobject3
python3-cairo             | python-cairo               | =                              | ~      | =                                   | py3-cairo
python3-numpy             | python-numpy               | =                              | ~      | =                                   | py3-numpy
gtk+3                     | gtk3                       | gir1.2-gtk-3.0                 | ~      | gtk3                                | gtk+3.0
adwaita-icon-theme        | =                          | =                              | ~      | =                                   | =
fontconfig                | =                          | =                              | ~      | =                                   | =
dejavu-fonts-ttf          | ttf-dejavu                 | fonts-dejavu-core              | ~      | dejavu-sans-fonts dejavu-sans-mono-fonts | font-dejavu
desktop-file-utils        | =                          | =                              | ~      | =                                   | =
git                       | =                          | =                              | ~      | =                                   | =
curl                      | =                          | =                              | ~      | =                                   | =
xz                        | =                          | xz-utils                       | ~      | =                                   | =
fzf                       | =                          | @bin:fzf                       | =      | =                                   | =
tmux                      | =                          | =                              | ~      | =                                   | =
ncurses                   | =                          | ncurses-bin                    | ~      | =                                   | =
bash                      | =                          | =                              | ~      | =                                   | =
base-tools                | procps-ng util-linux diffutils iproute2 | procps util-linux iproute2 | ~ | procps-ng util-linux iproute diffutils | coreutils util-linux procps-ng grep sed gawk findutils diffutils iproute2 pciutils shadow tar
mesa-dri                  | mesa                       | libgl1-mesa-dri                | ~      | mesa-dri-drivers                    | mesa-dri-gallium
vulkan-loader             | vulkan-icd-loader          | libvulkan1                     | ~      | =                                   | =
mesa-vulkan-intel         | vulkan-intel               | mesa-vulkan-drivers            | ~      | mesa-vulkan-drivers                 | mesa-vulkan-intel
intel-video-accel         | intel-media-driver         | intel-media-va-driver          | ~      | libva-intel-media-driver            | intel-media-driver
mesa-vulkan-radeon        | vulkan-radeon              | mesa-vulkan-drivers            | ~      | mesa-vulkan-drivers                 | mesa-vulkan-ati
mesa-vaapi                | -                          | mesa-va-drivers                | -      | -                                   | mesa-va-gallium
xf86-video-amdgpu         | =                          | xserver-xorg-video-amdgpu      | ~      | xorg-x11-drv-amdgpu                 | =
xf86-video-ati            | =                          | xserver-xorg-video-ati         | ~      | xorg-x11-drv-ati                    | =
mesa-vulkan-nouveau       | vulkan-nouveau             | mesa-vulkan-drivers            | ~      | mesa-vulkan-drivers                 | mesa-vulkan-nouveau
pipewire                  | pipewire pipewire-pulse    | pipewire pipewire-pulse        | ~      | pipewire pipewire-pulseaudio        | pipewire pipewire-pulse
wireplumber               | =                          | =                              | ~      | =                                   | =
alsa-pipewire             | pipewire-alsa              | pipewire-alsa                  | ~      | pipewire-alsa                       | pipewire-alsa
pulseaudio-utils          | libpulse                   | =                              | ~      | =                                   | =
pulsemixer                | =                          | =                              | ~      | -                                   | =
NetworkManager            | networkmanager             | network-manager                | ~      | =                                   | networkmanager networkmanager-wifi networkmanager-cli networkmanager-openrc
libnm                     | =                          | gir1.2-nm-1.0                  | ~      | NetworkManager-libnm                | =
NetworkManager-openvpn    | networkmanager-openvpn     | network-manager-openvpn        | ~      | =                                   | networkmanager-openvpn
NetworkManager-vpnc       | networkmanager-vpnc        | network-manager-vpnc           | ~      | =                                   | -
network-manager-applet    | nm-connection-editor       | network-manager-gnome          | ~      | nm-connection-editor                | =
bluez                     | bluez bluez-utils          | =                              | ~      | =                                   | bluez bluez-openrc
libspa-bluetooth          | -                          | libspa-0.2-bluetooth           | ~      | -                                   | pipewire-spa-bluez
brightnessctl             | =                          | =                              | ~      | =                                   | =
neovim                    | =                          | @bin:neovim                    | =      | =                                   | =
gcc                       | =                          | =                              | ~      | =                                   | gcc musl-dev
make                      | =                          | =                              | ~      | =                                   | =
tree-sitter-cli           | =                          | @bin:tree-sitter               | =      | =                                   | =
ripgrep                   | =                          | =                              | ~      | =                                   | =
fd                        | =                          | fd-find                        | ~      | fd-find                             | =
unzip                     | =                          | =                              | ~      | =                                   | =
nodejs                    | nodejs npm                 | nodejs npm                     | ~      | nodejs nodejs-npm                   | nodejs npm
openjdk21                 | jdk21-openjdk              | openjdk-21-jdk                 | ~      | java-25-openjdk-devel               | =
firefox                   | =                          | firefox-esr                    | firefox | =                                  | =
noto-fonts-emoji          | =                          | fonts-noto-color-emoji         | ~      | google-noto-color-emoji-fonts       | font-noto-emoji
neomutt                   | =                          | =                              | ~      | =                                   | =
mpv                       | =                          | =                              | ~      | =                                   | =
mpv-mpris                 | =                          | =                              | ~      | =                                   | =
playerctl                 | =                          | =                              | ~      | =                                   | =
ffmpeg                    | =                          | =                              | ~      | ffmpeg-free                         | =
chafa                     | =                          | =                              | ~      | =                                   | =
python3-Pillow            | python-pillow              | python3-pil                    | ~      | python3-pillow                      | py3-pillow
htop                      | =                          | =                              | ~      | =                                   | =
xdg-utils                 | =                          | =                              | ~      | =                                   | =
os-prober                 | =                          | =                              | ~      | =                                   | =
ntfs-3g                   | =                          | =                              | ~      | =                                   | =
dosfstools                | =                          | =                              | ~      | =                                   | =
wimlib                    | =                          | wimtools                       | ~      | wimlib-utils                        | =
gnupg                     | =                          | gpg                            | ~      | gnupg2                              | =
'
