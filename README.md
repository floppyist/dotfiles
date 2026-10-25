# Dotfiles (i3wm)

A minimalist and functional development environment based on **i3wm**, **Polybar**, and **Neovim**.

> [!CAUTION]
> This project is currently a **Work in Progress (WIP)**.
> Features may be incomplete and bugs are to be expected.
> Especially the Firefox configuration isn't in a production-ready state!

<p align="center">
    <img src="screenshots/general.png" />
</p>

<p align="center">
    <img src="screenshots/browser.png" />
</p>

<p align="center">
    <img src="screenshots/mpv-wrapper.png" />
</p>


## Components

- **Window Manager:** `i3wm` (with `picom`)
- **Terminal:** `Alacritty`
- **Editor:** `Neovim` (LazyVim distribution)
- **Status Bar:** `Polybar` (includes custom Bluetooth, WLAN, Display and Screenshot modules)
- **Notifications:** `Dunst`
- **Application Launcher:** `Rofi`
- **Browser:** `Firefox` (custom `userChrome.css`/`userContent.css`)
- **Scripts:**
  - `Bluetooth` Switch / Scan
  - `WiFi` Switch / Scan  
  - `Display` Switch
  - `Screenshot`
  - `Screensaver`

## Installation

### 1. Install packages (Void Linux)

```bash
sudo xbps-install -S \
i3-gaps i3lock-color polybar rofi dunst picom alacritty \
pipewire wireplumber libspa-bluetooth \
bluez rfkill NetworkManager nm-applet mpv mpv-mpris \
feh ncurses caffeine-ng
```

### 2. Clone the repository

Set `DOTFILES` to the directory you clone into. All following commands use this variable. Replace the path with your own if you don't want `~/dotfiles`. The variable only lasts for the current shell, so set it again in new shells.

```bash
export DOTFILES=~/dotfiles
git clone https://github.com/floppyist/dotfiles "$DOTFILES"
cd "$DOTFILES"
```

### 3. Symlink all configuration files and scripts

```bash
mkdir -p ~/.config
ln -s "$DOTFILES"/config/* ~/.config/
ln -s "$DOTFILES"/firefox/userChrome.css ~/.config/mozilla/firefox/<your-profile>/chrome/
ln -s "$DOTFILES"/firefox/userContent.css ~/.config/mozilla/firefox/<your-profile>/chrome/
ln -s "$DOTFILES"/.bashrc ~
ln -s "$DOTFILES"/.inputrc ~
ln -s "$DOTFILES"/.xinitrc ~
ln -s "$DOTFILES"/.Xresources ~

mkdir -p ~/.local/bin
ln -s "$DOTFILES"/scripts/* ~/.local/bin/

mkdir -p ~/.local/share/applications
ln -s "$DOTFILES"/applications/* ~/.local/share/applications/
```

### 4. Make scripts executable

```bash
chmod +x "$DOTFILES"/scripts/*
```

> **Note:** `~/.local/bin` must be in your `$PATH`. `.xinitrc` and `.bashrc` both export it. The `.desktop` launchers rely on this, so start i3 through `.xinitrc`.

### 5. Adjust machine-specific paths

The game and application launchers in `applications/` (`aseprite`, `cncgenerals*`, `factorio`, `wow`) point to install locations under `/home/floppyist/`. Change `Exec=` and `Path=` to match your system before linking them.

### 6. Enable custom styles in Firefox:

- Open `about:config`
- Set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`

## Optional steps: Enable/Disable vim mode in CLI

- Open `.bashrc`
- Add/Delete: `set -o vi`
