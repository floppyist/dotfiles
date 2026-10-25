# Dotfiles (i3wm)

A minimalist and functional development environment based on **i3wm**, **Polybar**, and **Neovim**.
One palette across the whole desktop: gruvbox colors on a dark teal-black (`#191c1c`), sharp corners,
JetBrainsMono Nerd Font everywhere, red (`#cc241d`) as the single accent.

<!-- Gallery: 3 x 240 px fits the README column on GitHub (830 px); click a picture for full size -->
<div align="center">
<table>
  <tr>
    <td align="center"><a href="screenshots/general.png"><img src="screenshots/general.png" width="240" alt="Desktop: i3, Polybar, Alacritty"></a><br><sub><b>Desktop</b> · i3, Polybar, Alacritty</sub></td>
    <td align="center"><a href="screenshots/dunst.png"><img src="screenshots/dunst.png" width="240" alt="Notifications: Dunst, volume OSD"></a><br><sub><b>Notifications</b> · Dunst, volume OSD</sub></td>
    <td align="center"><a href="screenshots/browser.png"><img src="screenshots/browser.png" width="240" alt="Firefox: userChrome.css"></a><br><sub><b>Firefox</b> · userChrome.css</sub></td>
  </tr>
  <tr>
    <td align="center"><a href="screenshots/lazyvim.png"><img src="screenshots/lazyvim.png" width="240" alt="Neovim: LazyVim"></a><br><sub><b>Neovim</b> · LazyVim</sub></td>
    <td align="center"><a href="screenshots/mpv-wrapper.png"><img src="screenshots/mpv-wrapper.png" width="240" alt="Music: mpvim with album cover"></a><br><sub><b>Music</b> · mpvim with album cover</sub></td>
    <td align="center"><a href="screenshots/nerdsaver-modes.png"><img src="screenshots/nerdsaver-modes.png" width="240" alt="Screensaver: nerdsaver"></a><br><sub><b>Screensaver</b> · nerdsaver</sub></td>
  </tr>
</table>
</div>

## Components

- **Settings:** one file, [`dotfiles.conf`](dotfiles.conf): accent color, palette, fonts, sizes, gaps, idle times, keyboard layout, terminal, wallpaper (see [Settings](#settings))
- **Window Manager:** `i3wm` (with `picom`)
- **Terminal:** `Alacritty`; shell: `bash` with a two-line git prompt and vi mode (readline's own plus vim text objects like `ciw`, `di"`, `ya(`; the prompt shows the mode); `fzf` in the same style
- **Editor:** `Neovim` (LazyVim distribution, gruvbox; sharp frames, rofi-style Telescope, mode blocks in the statusline)
- **Multiplexer:** `tmux` (prefix `Ctrl+a`; status line like Polybar)
- **Status Bar:** `Polybar` (grouped modules; WiFi/IP/Bluetooth with click menus, CPU/memory turn red under load, music, tray). Event-driven: updates arrive the moment something changes, nothing polls in the background (see below)
- **Notifications:** `Dunst` (per-app headers, volume/brightness on-screen bar, new mail from `neomutt`)
- **Launcher and menus:** `Rofi` (fzf-style; one shared menu helper for all system menus)
- **Lock / idle:** `xss-lock` + `nerdsaver` screensaver + `i3lock-color` (clock, input line instead of a ring, status texts below it)
- **Browser:** `Firefox` (custom `userChrome.css`/`userContent.css`)
- **GTK apps:** Adwaita dark with the desktop palette on top (file dialogs, tray menus, polkit prompts)
- **Mail:** `neomutt` (theme in `config/mutt/theme.muttrc`, accounts stay in `~/.muttrc`)
- **Music:** `mpvim` (vim-style terminal UI for `mpv`, shows the album cover: embedded or `cover.jpg`; sharper with `chafa` installed, `:cover` toggles it)
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
| `Alt + space` | Focus between tiled and floating windows |
| `Alt + r` | Resize mode |
| `Alt + Shift + q` | Kill window |
| `Alt + Shift + r` | Restart i3 |
| `Alt + Shift + e` | Power menu (lock, suspend, log out, reboot, shut down) |
| `Super + l` | Lock screen |
| `Super + p` | Display menu |
| `Super + b` (or the display function key) | Bluetooth on/off |
| `Print` / `Shift + Print` | Screenshot / region screenshot (also copied to the clipboard) |
| Volume / brightness keys | Change value, shows an on-screen bar |

Polybar: click WiFi or Bluetooth for their menus (right-click Bluetooth toggles it), click the IP address to
copy it, right-click volume for `pulsemixer`, click the music module to play/pause (right-click: next), click
the clock for the date.

Terminal tools started from Rofi (audio, calculus, htop, mutt, notice) open as a centered floating window
(`terminal.sh --float`, using the terminal from `dotfiles.conf`).

Shell (vim mode): `Esc` switches to normal mode (block cursor, `❮`), `i`/`a` back to insert mode (bar cursor, `❯`).
In normal mode the readline vi commands work (motions, `c`/`d`/`y`, counts, `p`, `u`, `.`) plus the text
objects `iw aw iW aW i" a" i' a'` `` i` a` `` `i( a( i[ a[ i{ a{ i< a<` (also `ib`, `iB`) after `c`, `d` or `y`.
`v` opens the line in Neovim (`$VISUAL`, visual mode and everything else), it runs when you save and quit.
`Up`/`Down` search the history for lines starting with what is typed; `Ctrl+r` (history), `Ctrl+t` (files)
and `Alt+c` (cd) use fzf. They open it in place of the prompt's second line (`╰─ history ❯`), and fzf looks like
Rofi everywhere (input line on top, accent bar on the selected row, colors from `dotfiles.conf`).
All of it is readline itself (`~/.inputrc`, `config/bash/vim.bash`): nothing runs
while you type, a new shell starts in about 20 ms.

## Settings

All basic settings live in [`dotfiles.conf`](dotfiles.conf) in the repository root. After editing it, run:

```bash
dotfiles apply      # or: dotfiles edit (opens the file, applies after saving)
```

`dotfiles apply` checks every value (unknown keys and invalid values are reported, nothing is changed then),
renders `templates/*` into `~/.config/dotfiles/`, and reloads i3, Polybar, dunst and tmux. Alacritty, Rofi and fzf
pick the change up by themselves, Neovim, GTK programs, Firefox and open shells on their next start. Idle times and the
keyboard layout are applied immediately.

| Group | Keys |
| --- | --- |
| Colors | `accent` (gruvbox name like `red`, `blue`, `aqua` or `#rrggbb`), `accent_text`, `bg`, `surface`, `overlay`, `fg`, `subtle`, `muted` |
| Fonts | `font` (a Nerd Font), `font_size_terminal`, `font_size_bar`, `font_size_menu`, `font_size_notify`, `font_size_window` |
| Layout | `bar_height`, `border_width`, `gaps`, `terminal_opacity`, `terminal_padding_x`, `terminal_padding_y` |
| Behaviour | `terminal`, `keyboard_layout`, `wallpaper`, `screensaver_after`, `lock_after`, `display_off_after` |

Other commands: `dotfiles check`, `dotfiles get accent`, `dotfiles list`.

The configs include the generated files (`include ~/.config/dotfiles/i3.conf`, `include-file` in Polybar,
`@import` in Rofi and GTK, `import` in Alacritty, `source-file` in tmux, `FZF_DEFAULT_OPTS_FILE` for fzf, a drop-in in
`~/.config/dunst/dunstrc.d/`).
To change the design itself, edit the configs or the templates in `templates/`.

### Polybar updates

| Module | Updated by |
| --- | --- |
| Workspaces, volume | Polybar itself (i3 IPC, PulseAudio events) |
| Brightness | the brightness keys (IPC hook) |
| Music | `playerctl --follow`: once per second while playing, nothing while paused |
| WiFi, IP, Bluetooth, battery | `polybar-watch` with `nmcli monitor`, `ip monitor`, `gdbus monitor` (bluez), `udevadm monitor` (charger, battery); plus a slow fallback refresh |
| CPU, memory, temperature, clock | sampled inside Polybar (reads `/proc`, starts no programs) |

## Idle and lock

| When | What happens |
| --- | --- |
| 60 s idle | Screensaver (`nerdsaver`), any input ends it |
| 300 s idle | Screen locks, display turns off |
| (change) | `screensaver_after`, `lock_after`, `display_off_after` in `dotfiles.conf` |
| Suspend, lid close, `loginctl lock-session` | Screen locks **before** the system sleeps |

`xss-lock` owns the locking (see `config/i3/config`). Fullscreen windows and `caffeine-ng` keep the screen awake.
Notifications are paused while the screen is locked.

## Dependencies

Package names are for Void Linux. Some binaries (e.g. `xprintidle`, the Nerd Font) may have different names on your distribution.

```bash
sudo xbps-install -S \
i3 i3lock-color xss-lock polybar rofi dunst picom alacritty feh \
xsetroot xset xrandr xclip scrot xbanish xprintidle \
pipewire wireplumber libspa-bluetooth pulsemixer \
bluez rfkill NetworkManager libnotify elogind polkit-gnome \
mpv mpv-mpris playerctl brightnessctl \
neomutt fzf ncurses caffeine-ng python3 tmux ffmpeg
```

Optional: `chafa` (sharper album covers in `mpvim`; without it they are drawn with half blocks via
`python3-Pillow`).

Minimum versions: i3 4.22, polybar 3.6, picom 12 (uses the `rules` syntax), rofi 1.7, dunst 1.9, scrot 1.7, bash 5.1 (text objects; 5.3 keeps the chevron off continuation lines),
tmux 3.2, alacritty 0.14 (`[general] import`), fzf 0.66 (`--gutter`).

Also needed:
- `calculus` (built separately, expects `~/.local/bin/calculus`)
- JetBrainsMono Nerd Font (v3, `md-*` icons; on Void in `nerd-fonts-ttf`)
- Optional: the `Bibata-Modern-Classic` cursor theme (e.g. in `~/.icons`; without it X shows its default cursor)
- Wallpaper at `~/images/wallpaper` (or set `wallpaper` in `dotfiles.conf`); screenshots go to `~/images/screenshots`
- Optional: `numpy` for the pixel screensavers of `nerdsaver`, Wine for the games in `applications/local/`

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

The script links every file of `config/` into `~/.config/` (file by file, e.g. `~/.config/i3/config`, so your own files in those directories stay), the dotfiles into `~/`, the scripts into `~/.local/bin/` and the `.desktop` files into `~/.local/share/applications/` (those in `applications/local/` only if their program is installed, see step 5). It makes the scripts executable and runs `dotfiles apply` once. Existing files it would replace are moved to `*.bak-<timestamp>`; links to files that were removed from the repository are deleted. It can be run again safely (also after `git pull`, to link new files).

Everything is linked, not copied: switching git branches changes the running desktop (Alacritty reloads its config live, scripts and Rofi pick up changes on their next start).

`~/.local/bin` must be in your `$PATH`. `.xinitrc` and `.bashrc` both export it. The `.desktop` launchers and the scripts rely on this, so start i3 through `.xinitrc`.

### 4. Manual steps

- **udev** (backlight permissions, needs root):
  ```bash
  sudo install -m644 "$DOTFILES/config/udev/90-backlight.rules" /etc/udev/rules.d/
  sudo udevadm control --reload-rules
  ```
- **Firefox:** open `about:config`, set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`, then link `firefox/userChrome.css` and `firefox/userContent.css` into `<your-profile>/chrome/` and run `dotfiles apply` (it links the generated colors next to them as `dotfiles.css`).
- **neomutt:** add these lines to `~/.muttrc` (after your account settings, so the theme wins):
  ```
  source ~/.config/mutt/notify.muttrc   # new-mail notifications
  source ~/.config/mutt/theme.muttrc    # colors, formats, flag glyphs
  ```
  Remove your own `color`, `index_format`, `status_format`, `status_chars` and `to_chars` lines, the theme sets them.
- **Neovim:** the gruvbox colorscheme is installed by lazy.nvim on the first start (needs network).

### 5. Adjust machine-specific paths

The launchers in `applications/local/` (Aseprite, Command & Conquer Generals, Factorio, World of Warcraft, Sunshine) are
machine-specific and point to install locations under `/home/floppyist/`. `install.sh` links one only if its program
exists (the command of `Exec=` and `TryExec=`, every absolute path in `Exec=` and `Path=`) and removes the link again
when it is gone, so they never show up as broken entries in Rofi. Change `Exec=` and `Path=` to your install
locations (or put your own launchers there) and run `./install.sh` again.

## Security notes

- The screen is locked before suspend (`xss-lock --transfer-sleep-lock`), so no content is visible on resume. If `i3lock-color` fails, plain `i3lock` is used; if that fails too, a critical notification says that the screen is **not** locked.
- Text that other people control (song titles from websites, WiFi names, Bluetooth device names) is sanitized before it reaches Polybar, which would otherwise interpret `%{A:…:}` tags as clickable shell commands.
- System menus never act on typed text that matches no entry (`rofi -no-custom`), so a typo cannot select a random network or display mode.
- The git prompt runs `git status` with `core.fsmonitor=false`, so a repository's own config cannot start a program when you `cd` into it.
- Runtime files (mpv IPC socket, screensaver log/lock) live in private directories, not under predictable names in `/tmp`.
- `dotfiles.conf` values end up in configs that can run commands (i3, Polybar, tmux, shell), so `dotfiles apply` only accepts strict patterns (colors `#rrggbb`, numbers in a range, fonts and paths without quotes or shell characters).
- A command typed with a leading space is not saved in the bash history.

## Troubleshooting

- **Bluetooth "Failed to power on":** the Intel AX200 (`btusb`) can get stuck after rfkill cycles. Reload the driver with `sudo modprobe -r btusb && sudo modprobe btusb`, or reboot.
- **Idle lock after updating these dotfiles:** `xss-lock` only starts with the session. Log out and back in once (an i3 restart is not enough).
- **Previous Neovim colors:** set `colorscheme = "catppuccin-frappe"` in `config/nvim/lua/plugins/colorscheme.lua`.
- **Colors look like defaults (dunst, Rofi, Alacritty):** the generated files are missing. Run `dotfiles apply`.
- **GTK program still light or unchanged:** GTK reads `~/.config/gtk-3.0/` only when a program starts; restart it. Tools like `lxappearance` replace the linked `settings.ini` with their own file, run `./install.sh` again to restore the link (your file is kept as a backup).

## Optional steps: Enable/Disable vim mode in CLI

- Open `.bashrc`
- Add/Delete: `set -o vi` (without it bash uses the emacs keys; the prompt then always shows `❯`)
