# Dotfiles (i3wm)

A minimalist and functional development environment based on **i3wm**, **Polybar**, and **Neovim**.
One palette across the whole desktop: gruvbox colors on a dark teal-black (`#191c1c`), sharp corners,
JetBrainsMono Nerd Font everywhere, red (`#cc241d`) as the single accent.

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
- **Editor:** `Neovim` (LazyVim distribution, gruvbox)
- **Status Bar:** `Polybar` (grouped modules; WiFi/Bluetooth click menus, CPU/memory turn red under load, music, tray)
- **Notifications:** `Dunst` (per-app headers, volume/brightness on-screen bar, new mail from `neomutt`)
- **Launcher and menus:** `Rofi` (fzf-style; one shared menu helper for all system menus)
- **Lock / idle:** `xss-lock` + `nerdsaver` screensaver + `i3lock-color`
- **Browser:** `Firefox` (custom `userChrome.css`/`userContent.css`)
- **Mail:** `neomutt` (theme in `config/mutt/theme.muttrc`, accounts stay in `~/.muttrc`)
- **Music:** `mpvim` (vim-style terminal UI for `mpv`)
- **Scripts:** Bluetooth, WiFi, Display (Windows-style), Power menu, Volume/Brightness OSD, Screenshot, Screensaver, Mail notifications

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
| `Alt + Shift + r` | Restart i3 |
| `Alt + Shift + e` | Power menu (lock, suspend, log out, reboot, shut down) |
| `Super + l` | Lock screen |
| `Super + p` | Display menu |
| `Super + b` (or the display function key) | Bluetooth on/off |
| `Print` / `Shift + Print` | Screenshot / region screenshot (also copied to the clipboard) |
| Volume / brightness keys | Change value, shows an on-screen bar |

Polybar: click WiFi or Bluetooth for their menus (right-click Bluetooth toggles it), right-click volume for
`pulsemixer`, click the music module to play/pause (right-click: next), click the clock for the date.

Terminal tools started from Rofi (audio, calculus, htop, mutt) open as a centered floating window.

## Idle and lock

| When | What happens |
| --- | --- |
| 60 s idle | Screensaver (`nerdsaver`), any input ends it |
| 300 s idle | Screen locks, display turns off |
| Suspend, lid close, `loginctl lock-session` | Screen locks **before** the system sleeps |

`xss-lock` owns the locking (see `config/i3/config`). Fullscreen windows and `caffeine-ng` keep the screen awake.
Notifications are paused while the screen is locked.

## Dependencies

Package names are for Void Linux. Some binaries (e.g. `xprintidle`, the Nerd Font) may have different names on your distribution.

```bash
sudo xbps-install -S \
i3 i3lock-color xss-lock polybar rofi dunst picom alacritty feh \
xsetroot xset xrandr xclip scrot xbanish xprintidle \
pipewire wireplumber pipewire-pulse libspa-bluetooth pulsemixer \
bluez rfkill NetworkManager nm-applet libnotify elogind polkit-gnome \
mpv mpv-mpris playerctl brightnessctl \
neomutt fzf ncurses caffeine-ng python3
```

Minimum versions: i3 4.22, polybar 3.6, picom 12 (uses the `rules` syntax), rofi 1.7, dunst 1.9, scrot 1.7, bash 5.

Also needed:
- `calculus` (built separately, expects `~/.local/bin/calculus`)
- JetBrainsMono Nerd Font (v3, `md-*` icons)
- Wallpaper at `~/images/wallpaper`; screenshots go to `~/images/screenshots`
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

Everything is linked, not copied: switching git branches changes the running desktop (Alacritty reloads its config live, scripts and Rofi pick up changes on their next start).

`~/.local/bin` must be in your `$PATH`. `.xinitrc` and `.bashrc` both export it. The `.desktop` launchers and the scripts rely on this, so start i3 through `.xinitrc`.

### 4. Manual steps

- **udev** (backlight permissions, needs root):
  ```bash
  sudo install -m644 "$DOTFILES/config/udev/90-backlight.rules" /etc/udev/rules.d/
  sudo udevadm control --reload-rules
  ```
- **Firefox:** open `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`, then link `firefox/userChrome.css` and `firefox/userContent.css` into `<your-profile>/chrome/`.
- **neomutt:** add these lines to `~/.muttrc` (after your account settings, so the theme wins):
  ```
  source ~/.config/mutt/notify.muttrc   # new-mail notifications
  source ~/.config/mutt/theme.muttrc    # colors, formats, flag glyphs
  ```
  Remove your own `color`, `index_format`, `status_format`, `status_chars` and `to_chars` lines, the theme sets them.
- **Neovim:** the gruvbox colorscheme is installed by lazy.nvim on the first start (needs network).

### 5. Adjust machine-specific paths

The launchers in `applications/` (`aseprite`, `cncgenerals*`, `factorio`, `wow`) point to install locations under `/home/floppyist/`. Change `Exec=` and `Path=` to match your system.

## Security notes

- The screen is locked before suspend (`xss-lock --transfer-sleep-lock`), so no content is visible on resume. If `i3lock-color` fails, plain `i3lock` is used; if that fails too, a critical notification says that the screen is **not** locked.
- Text that other people control (song titles from websites, WiFi names, Bluetooth device names) is sanitized before it reaches Polybar, which would otherwise interpret `%{A:…:}` tags as clickable shell commands.
- System menus never act on typed text that matches no entry (`rofi -no-custom`), so a typo cannot select a random network or display mode.
- The git prompt runs `git status` with `core.fsmonitor=false`, so a repository's own config cannot start a program when you `cd` into it.
- Runtime files (mpv IPC socket, screensaver log/lock) live in private directories, not under predictable names in `/tmp`.
- A command typed with a leading space is not saved in the bash history.

## Troubleshooting

- **Bluetooth "Failed to power on":** the Intel AX200 (`btusb`) can get stuck after rfkill cycles. Reload the driver with `sudo modprobe -r btusb && sudo modprobe btusb`, or reboot.
- **Idle lock after updating these dotfiles:** `xss-lock` only starts with the session. Log out and back in once (an i3 restart is not enough).
- **Previous Neovim colors:** set `colorscheme = "catppuccin-frappe"` in `config/nvim/lua/plugins/colorscheme.lua`.

## Optional steps: Enable/Disable vim mode in CLI

- Open `.bashrc`
- Add/Delete: `set -o vi`
