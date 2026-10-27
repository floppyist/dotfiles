#!/bin/bash

# Values from dotfiles.conf (keyboard layout, cursor size); defaults until `dotfiles apply` ran
DF_KEYBOARD_LAYOUT=de
DF_CURSOR_SIZE=64
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null

xrdb -merge ~/.Xresources

# Cursor theme drawn by `dotfiles apply` into ~/.icons/dotfiles (scripts/dotfiles-cursors)
xrdb -merge <<< "Xcursor.size: $DF_CURSOR_SIZE"
export XCURSOR_SIZE=$DF_CURSOR_SIZE
export XCURSOR_THEME=dotfiles
export MOZ_USE_XINPUT2=0
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

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
