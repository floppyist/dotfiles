#!/usr/bin/env bash
# Link the dotfiles into place.
# - Idempotent: running it again changes nothing that is already correct.
# - Existing files/directories that would be replaced are moved to *.bak-<timestamp>.
# - Does not touch /etc (udev rule) or Firefox profiles; those are printed as hints.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

link() {
    local src=$1 dst=$2
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        mv "$dst" "$dst.bak-$STAMP"
        echo "backup  $dst -> $dst.bak-$STAMP"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "link    $dst -> $src"
}

# ~/.config/<name>
for src in "$DOTFILES"/config/*; do
    name="$(basename "$src")"
    [[ "$name" == "udev" ]] && continue
    link "$src" "$HOME/.config/$name"
done

# Dotfiles in $HOME
for name in .bashrc .inputrc .xinitrc .Xresources; do
    link "$DOTFILES/$name" "$HOME/$name"
done

# Scripts -> ~/.local/bin
for src in "$DOTFILES"/scripts/*; do
    link "$src" "$HOME/.local/bin/$(basename "$src")"
done

# Desktop entries -> ~/.local/share/applications
for src in "$DOTFILES"/applications/*.desktop; do
    link "$src" "$HOME/.local/share/applications/$(basename "$src")"
done

# Executable bits (git tracks them, this is for fresh clones)
chmod +x "$DOTFILES"/scripts/* "$DOTFILES"/config/polybar/launch.sh

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

cat <<EOF

Done. Manual steps that this script does not do:
  - udev (backlight permissions, needs root):
      sudo install -m644 "$DOTFILES/config/udev/90-backlight.rules" /etc/udev/rules.d/
      sudo udevadm control --reload-rules
  - Firefox: link firefox/userChrome.css and firefox/userContent.css into <profile>/chrome/
  - Mutt: add to ~/.muttrc:  source ~/.config/mutt/notify.muttrc
  - Make sure ~/.local/bin is in PATH (.xinitrc and .bashrc export it).
EOF
