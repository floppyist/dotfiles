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
- **Notifications:** `Dunst` (also shows new mail from `neomutt`)
- **Application Launcher:** `Rofi`
- **Browser:** `Firefox` (custom `userChrome.css`/`userContent.css`)
- **Scripts:**
  - `Bluetooth` Switch / Scan
  - `WiFi` Switch / Scan
  - `Display` Menu (Windows-style: PC only, duplicate, extend, second screen only)
  - `Screenshot`
  - `Screensaver`
  - `Mail` notifications

## Keybindings

`Alt` is the window-manager modifier (`Mod1`), `Super` (`Mod4`) is used for system actions.

| Key | Action |
| --- | --- |
| `Alt + Return` | Terminal |
| `Alt + d` | Launcher (Rofi) |
| `Alt + h/j/k/l` | Focus (`Alt + Shift + h/j/k/l` moves) |
| `Alt + 1..5` | Workspace (`Alt + Shift + 1..5` moves window) |
| `Alt + b` / `Alt + v` | Split horizontal / vertical |
| `Alt + f` | Fullscreen |
| `Alt + Shift + space` | Toggle floating |
| `Alt + r` | Resize mode |
| `Alt + Shift + q` | Kill window |
| `Alt + Shift + r` / `Alt + Shift + e` | Restart / exit i3 |
| `Super + l` | Lock screen |
| `Super + p` (or display key) | Display menu |
| `Super + b` | Bluetooth toggle |
| `Print` | Screenshot |

Terminal tools started from Rofi (audio, calculus, htop, mutt) open as a centered floating window.

## Dependencies

Package names are for Void Linux. Some binaries (e.g. `xprintidle`, the Nerd Font) may have different names on your distribution.

```bash
sudo xbps-install -S \
i3-gaps i3lock-color polybar rofi dunst picom alacritty feh \
xsetroot xset xrandr xclip scrot xss-lock xbanish xprintidle \
pipewire wireplumber pipewire-pulse libspa-bluetooth pulsemixer \
bluez rfkill NetworkManager nm-applet libnotify \
mpv mpv-mpris playerctl brightnessctl \
neomutt fzf ncurses caffeine-ng
```

Also needed:
- `calculus` (built separately, expects `~/.local/bin/calculus`)
- JetBrainsMono Nerd Font
- Wallpaper at `~/images/wallpaper` and screenshots go to `~/images/screenshots`
- Optional: `numpy` for the pixel screensavers of `nerdsaver`, Wine for the games in `applications/`

## Installation

### 1. Install packages

See [Dependencies](#dependencies).

### 2. Clone the repository

Set `DOTFILES` to the directory you clone into. Replace the path with your own if you don't want `~/dotfiles`. The variable only lasts for the current shell.

```bash
export DOTFILES=~/dotfiles
git clone https://github.com/floppyist/dotfiles "$DOTFILES"
cd "$DOTFILES"
```

### 3. Link everything

```bash
./install.sh
```

The script links `config/*` into `~/.config/`, the dotfiles into `~/`, the scripts into `~/.local/bin/` and the `.desktop` files into `~/.local/share/applications/`. It makes the scripts executable. Existing files it would replace are moved to `*.bak-<timestamp>`. It can be run again safely.

`~/.local/bin` must be in your `$PATH`. `.xinitrc` and `.bashrc` both export it. The `.desktop` launchers rely on this, so start i3 through `.xinitrc`.

### 4. Manual steps

- **udev** (backlight permissions, needs root):
  ```bash
  sudo install -m644 "$DOTFILES/config/udev/90-backlight.rules" /etc/udev/rules.d/
  sudo udevadm control --reload-rules
  ```
- **Firefox:** open `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`, then link `firefox/userChrome.css` and `firefox/userContent.css` into `<your-profile>/chrome/`.
- **Mail notifications:** add this line to `~/.muttrc`:
  ```
  source ~/.config/mutt/notify.muttrc
  ```

### 5. Adjust machine-specific paths

The launchers in `applications/` (`aseprite`, `cncgenerals*`, `factorio`, `wow`) point to install locations under `/home/floppyist/`. Change `Exec=` and `Path=` to match your system.

## Troubleshooting

- **Bluetooth "Failed to power on":** the Intel AX200 (`btusb`) can get stuck after rfkill cycles. Reload the driver with `sudo modprobe -r btusb && sudo modprobe btusb`, or reboot.

## Optional steps: Enable/Disable vim mode in CLI

- Open `.bashrc`
- Add/Delete: `set -o vi`
