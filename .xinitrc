#!/bin/bash

xrdb -merge ~/.Xresources

export XCURSOR_SIZE=32
export XCURSOR_THEME=Bibata-Modern-Classic
export MOZ_USE_XINPUT2=0
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

xsetroot -cursor_name left_ptr

# Keyboard layout from dotfiles.conf (`keyboard_layout`, e.g. de or us,de or de(nodeadkeys))
DF_KEYBOARD_LAYOUT=de
. "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
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
