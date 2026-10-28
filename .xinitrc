#!/bin/bash

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Monitors first: the saved layout for the connected ones (`displays`, Super+Shift+p), then
# dotfiles.conf rendered for it (scale = auto measures the primary monitor)
command -v displays >/dev/null && displays restore >/dev/null 2>&1
command -v dotfiles >/dev/null && dotfiles apply --no-reload >/dev/null 2>&1

# Values from dotfiles.conf (keyboard layout, scale, cursor size); defaults until `dotfiles apply` ran
DF_KEYBOARD_LAYOUT=de
DF_DPI=96
DF_GDK_SCALE=1
DF_GDK_DPI_SCALE=1.000
DF_CURSOR_SIZE_PX=32
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

xrdb -merge ~/.Xresources

# The scale: Xft.dpi for everything that draws text (i3, GTK, Qt, alacritty, Firefox, rofi,
# dunst). GTK draws its widgets at whole factors only: from scale 2 on, GDK_SCALE does that
# and GDK_DPI_SCALE takes the factor back out of the fonts.
xrdb -merge <<< "Xft.dpi: $DF_DPI"
if [[ "$DF_GDK_SCALE" =~ ^[2-4]$ ]]; then
    export GDK_SCALE=$DF_GDK_SCALE GDK_DPI_SCALE=$DF_GDK_DPI_SCALE
fi

# Cursor theme drawn by `dotfiles apply` into ~/.icons/dotfiles (scripts/dotfiles-cursors)
xrdb -merge <<< "Xcursor.size: $DF_CURSOR_SIZE_PX"
export XCURSOR_SIZE=$DF_CURSOR_SIZE_PX
export XCURSOR_THEME=dotfiles
export MOZ_USE_XINPUT2=0

xsetroot -cursor_name left_ptr

# Keyboard layout from dotfiles.conf (`keyboard_layout`, e.g. de or us,de or de(nodeadkeys))
layouts="" variants=""
IFS=, read -ra _kb <<< "$DF_KEYBOARD_LAYOUT"
for k in "${_kb[@]}"; do
    case "$k" in
        *"("*")") layouts+="${k%%(*},"; v=${k#*(}; variants+="${v%)}," ;;
        *)        layouts+="$k,"; variants+="," ;;
    esac
done
if [[ "$variants" == *[a-z]* ]]; then
    setxkbmap "${layouts%,}" -variant "${variants%,}"
else
    setxkbmap "${layouts%,}"
fi
unset _kb k v layouts variants

exec dbus-run-session i3
