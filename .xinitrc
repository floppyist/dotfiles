#!/bin/bash

xrdb -merge ~/.Xresources

export XCURSOR_SIZE=32
export XCURSOR_THEME=Bibata-Modern-Classic
export MOZ_USE_XINPUT2=0
export PATH="$HOME/.local/bin:$PATH"

xsetroot -cursor_name left_ptr

setxkbmap de

exec dbus-run-session i3
