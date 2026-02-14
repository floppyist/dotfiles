# Dotfiles (i3wm)

> [!CAUTION]
> This project is currently a **Work in Progress (WIP)**.
> Features may be incomplete and bugs are to be expected.

A minimalist and functional development environment based on **i3wm**, **Polybar**, and **Neovim** running on **Void Linux**.

## Components

- **Window Manager:** `i3wm` (with `i3blocks` & `picom`)
- **Terminal:** `Alacritty`
- **Editor:** `Neovim` (LazyVim distribution)
- **Status Bar:** `Polybar` (includes custom Bluetooth & WLAN modules)
- **Notifications:** `Dunst`
- **Application Launcher:** `Rofi`
- **Browser:** `Firefox` (custom `userChrome.css` for a minimal UI)
- **Scripts:**
    - `Bluetooth` Switch / Scan
    - `WiFi` Switch / Scan
    - `Display` Switch

## Installation
### 1. Install packages
```bash
sudo xbps-install -S \
  i3-gaps polybar rofi dunst picom alacritty \
  pipewire wireplumber libspa-bluetooth \
  bluez rfkill NetworkManager nm-applet mpv mpv-mpris
```

### 2. Clone the Repository
```bash
git clone https://github.com/floppyist/dotfiles ~/dotfiles
cd ~/dotfiles
```

### 3. Symlink All Configuration Files
Most configurations belong in the `~/.config` directory:
```bash
mkdir -p ~/.config
ln -s ~/dotfiles/config/* ~/.config/
ln -s ~/dotfiles/userChrome.css ~/.config/mozilla/firefox/<your-profile>/chrome/
ln -s ~/dotfiles/.bashrc ~
```

### 4. Install Scripts
Scripts should be placed in your local binary path:
```bash
mkdir -p ~/.local/bin
cp ~/dotfiles/scripts/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh
```

> **Note:** Ensure `~/.local/bin` is added to your `$PATH`.

Enable custom styles in Firefox:
- Open `about:config`
- Set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`
