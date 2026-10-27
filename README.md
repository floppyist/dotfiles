<!-- The images in assets/readme/ are drawn from dotfiles.conf: run assets/readme/render.py after changing the palette -->
<div align="center">
  <img src="assets/readme/banner.png" width="830" alt="dotfiles: a polybar with workspaces and status capsules, a VPN notification and the two-line shell prompt">
</div>

A complete i3wm desktop for **Void Linux** (X11, elogind): Polybar, Rofi, Dunst, Alacritty, tmux, Neovim and a
handful of scripts, all in one design. Gruvbox colors on a dark teal-black, one red accent, sharp corners and
JetBrainsMono Nerd Font everywhere. All of it comes from one settings file, [`dotfiles.conf`](dotfiles.conf).

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

## Contents

| Look | Daily use | Setup |
| --- | --- | --- |
| [Design](#design) | [Keybindings](#keybindings) | [Dependencies](#dependencies) |
| [Components](#components) | [Shell](#shell) | [Installation](#installation) |
| [Settings](#settings) | [Polybar](#polybar) | [Security notes](#security-notes) |
| [Idle and lock](#idle-and-lock) | [WiFi and VPN](#wifi-and-vpn) | [Troubleshooting](#troubleshooting) |

## Design

<img src="assets/readme/palette.png" width="830" alt="Palette: bg, surface, overlay, fg, subtle, muted, accent, accent_text and the bright gruvbox colors">

- **One accent** (`accent`, red by default) marks what is current or focused: the focused workspace, the clock,
  the directory in the prompt, the selected row (a `▌` bar, as in Rofi, fzf and mpvim), the cursor, progress bars.
  `accent_text` is the same color as text on dark backgrounds.
- **Grays have roles:** `surface` for capsules, input bars and selected rows, `overlay` for frames and separators,
  `subtle` for secondary text, `muted` for hints.
- **Bright gruvbox colors** identify things (the WiFi icon is aqua, volume blue, brightness yellow, a VPN tunnel
  green). Red, yellow and orange keep their meaning everywhere: error, warning, urgent.
- **Capsules:** Polybar, the prompt and the tmux status line group information in `surface` blocks with a colored
  icon, separated by a gap. Corners are sharp everywhere: windows, menus, notifications, GTK, Firefox and the
  mouse cursor.

> [!TIP]
> Change `accent = red` in `dotfiles.conf` to `blue`, `aqua` or any `#rrggbb` and run `dotfiles apply`: every
> component follows. `assets/readme/render.py` redraws the pictures of this README in the new colors.

## Components

| Part | What it is |
| --- | --- |
| **Settings** | one file, [`dotfiles.conf`](dotfiles.conf): accent, palette, fonts, sizes, gaps, idle times, keyboard layout, terminal, wallpaper (see [Settings](#settings)) |
| **Window manager** | `i3wm` with `picom` |
| **Terminal and shell** | `Alacritty`; `bash` with a two-line prompt in the Polybar style and vi mode with vim text objects; `fzf` in the Rofi style (see [Shell](#shell)) |
| **Editor** | `Neovim` (LazyVim, gruvbox; sharp frames, Rofi-style Telescope, mode blocks in the statusline) |
| **Multiplexer** | `tmux` (prefix `Ctrl+a`; status line like Polybar) |
| **Status bar** | `Polybar`: grouped capsules, menus for WiFi, VPN and Bluetooth, event-driven updates, hides the least important capsules when it gets too full (see [Polybar](#polybar)) |
| **Notifications** | `Dunst`: a colored header per app, volume/brightness bar, new mail from `neomutt` |
| **Launcher and menus** | `Rofi`, fzf-style; one shared menu helper for all system menus |
| **Network** | WiFi menu and the `vpn` tool for NetworkManager: WireGuard, OpenVPN, Cisco, FRITZ!Box (see [WiFi and VPN](#wifi-and-vpn)) |
| **Lock and idle** | `xss-lock`, the `nerdsaver` screensaver and `i3lock-color` (clock, input line instead of a ring, status texts) |
| **Browser** | `Firefox` (`userChrome.css`/`userContent.css` in the desktop colors) |
| **GTK apps** | Adwaita dark with the palette on top (file dialogs, tray menus, polkit prompts) |
| **Mouse cursor** | its own theme, drawn in the palette by `dotfiles apply` (`scripts/dotfiles-cursors`): sharp shapes, the busy indicator in the accent; `light`, `dark` or `accent` |
| **Mail** | `neomutt` (theme in `config/mutt/theme.muttrc`; accounts stay in `~/.muttrc`) |
| **Music** | `mpvim`, a vim-style terminal UI for `mpv` with the album cover (embedded or `cover.jpg`; sharper with `chafa`, `:cover` toggles it) |
| **Scripts** | Bluetooth, WiFi, VPN, display (Windows-style), power menu, volume/brightness OSD, screenshots (region or window on a frozen screen), screensaver, mail notifications |

## Keybindings

<kbd>Alt</kbd> is the window-manager modifier (`Mod1`), <kbd>Super</kbd> (`Mod4`) is used for system actions.

| Keys | Action |
| --- | --- |
| <kbd>Alt</kbd> <kbd>Return</kbd> | Terminal |
| <kbd>Alt</kbd> <kbd>d</kbd> | Launcher (Rofi) |
| <kbd>Alt</kbd> <kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd> | Focus (with <kbd>Shift</kbd>: move the window) |
| <kbd>Alt</kbd> <kbd>1</kbd> … <kbd>5</kbd> | Workspace (with <kbd>Shift</kbd>: move the window there) |
| <kbd>Alt</kbd> <kbd>b</kbd> / <kbd>Alt</kbd> <kbd>v</kbd> | Split horizontal / vertical |
| <kbd>Alt</kbd> <kbd>f</kbd> | Fullscreen |
| <kbd>Alt</kbd> <kbd>Shift</kbd> <kbd>Space</kbd> | Toggle floating |
| <kbd>Alt</kbd> <kbd>Space</kbd> | Focus between tiled and floating windows |
| <kbd>Alt</kbd> <kbd>r</kbd> | Resize mode (<kbd>h</kbd> <kbd>j</kbd> <kbd>k</kbd> <kbd>l</kbd>, leave with <kbd>Return</kbd> or <kbd>Esc</kbd>) |
| <kbd>Alt</kbd> <kbd>Shift</kbd> <kbd>q</kbd> | Close the window |
| <kbd>Alt</kbd> <kbd>Shift</kbd> <kbd>r</kbd> | Restart i3 |
| <kbd>Alt</kbd> <kbd>Shift</kbd> <kbd>e</kbd> | Power menu (lock, suspend, log out, reboot, shut down) |
| <kbd>Super</kbd> <kbd>l</kbd> | Lock the screen |
| <kbd>Super</kbd> <kbd>p</kbd> | Display menu |
| <kbd>Super</kbd> <kbd>b</kbd> (or the display function key) | Bluetooth on/off |
| <kbd>Super</kbd> <kbd>v</kbd> | VPN menu |
| <kbd>Print</kbd> / <kbd>Shift</kbd> <kbd>Print</kbd> | Screenshot / region screenshot (also copied to the clipboard) |
| Volume and brightness keys | Change the value, shows an on-screen bar |

**Region screenshot** (<kbd>Shift</kbd> <kbd>Print</kbd>): the screen freezes and dims, a bar at the top shows the
keys. Drag to take a region (its size is shown next to it), click to take the window under the pointer, <kbd>Return</kbd>
for the whole monitor, <kbd>Esc</kbd> or a right click to cancel. Lines through the pointer show where it is. Without
input it cancels itself after 30 s.

Terminal tools started from Rofi (audio mixer, htop, neomutt) open as a centered floating window
(`terminal.sh --float`, with the terminal from `dotfiles.conf`).

## Shell

The prompt has two lines (see the picture at the top). The first one is built like Polybar: `user@host` behind
an accent bar (a red `ROOT@host` block for root), the directory in the accent block (last directory bold), then
capsules for git (branch, changes, ahead/behind), the exit code or signal of the last command, background jobs
and the duration of commands that took 2 s or longer. The second line is the input line; its `▌` shows the vi mode.

- **Vi mode** (readline's own): <kbd>Esc</kbd> switches to normal mode (block cursor, yellow `▌`), <kbd>i</kbd>/<kbd>a</kbd>
  back to insert mode (bar cursor, accent `▌`). Motions, `c`/`d`/`y`, counts, `p`, `u`, `.` work, plus the text
  objects `iw aw iW aW i" a" i' a'` `` i` a` `` `i( a( i[ a[ i{ a{ i< a<` (also `ib`, `iB`) after `c`, `d` or `y`.
  <kbd>v</kbd> opens the line in Neovim (`$VISUAL`); it runs when you save and quit.
- **History and fzf:** <kbd>Up</kbd>/<kbd>Down</kbd> search the history for lines starting with what is typed;
  <kbd>Ctrl</kbd> <kbd>r</kbd> (history), <kbd>Ctrl</kbd> <kbd>t</kbd> (files) and <kbd>Alt</kbd> <kbd>c</kbd> (cd)
  open fzf in place of the second prompt line, styled like Rofi (input on top, accent bar on the selected row).
- **Fast:** all of it is readline itself (`~/.inputrc`, `config/bash/vim.bash`), nothing runs while you type, and the
  prompt starts no subshell (bash 5.3). A new shell starts in about 20 ms; `git` only runs inside a repository.
- **Emacs keys instead:** remove `set -o vi` from `.bashrc`; the prompt then always shows the insert-mode bar.

## Polybar

Click the WiFi, VPN or Bluetooth capsule for its menu; right-click VPN or Bluetooth to toggle it (VPN: the last
used profile). Click the IP address to copy it, the music to play/pause (right-click: next), the clock for the
full date; right-click the volume for `pulsemixer`.

**When the bar gets too full** (a long song title, many workspaces, tray icons), Polybar would cut off the
right end, the clock first. `polybar-fit` measures both halves of the bar and hides capsules until everything
fits, in this order: CPU/memory/temperature, then volume/brightness, then music. They come back as soon as
there is room again. An empty capsule (the tray without icons) takes no gap.

**Nothing polls.** Every module updates when something changes:

| Module | Updated by |
| --- | --- |
| Workspaces, volume | Polybar itself (i3 IPC, PulseAudio events) |
| Brightness | the brightness keys (IPC hook) |
| Music | `playerctl --follow`: once per second while playing, nothing while paused |
| WiFi, IP, VPN, Bluetooth, battery | `polybar-watch` with `nmcli monitor`, `ip monitor`, `gdbus monitor` (bluez), `udevadm monitor` (charger, battery); plus a slow fallback refresh |
| CPU, memory, temperature, clock | sampled inside Polybar (reads `/proc`, starts no programs) |
| Overflow (`polybar-fit`) | inotify on the module outputs, i3 IPC events, X events of the tray |

## WiFi and VPN

**WiFi:** click the WiFi capsule (or start "wifi" in Rofi) and pick a network (`●` connected, a lock icon for
secured ones). A saved profile is used as it is; for a new network, or when the saved password is rejected, Rofi
asks for the password (three attempts). WPA-Enterprise networks (eduroam) need `nm-connection-editor`.

**VPN:** <kbd>Super</kbd> <kbd>v</kbd> or a click on the shield opens the menu: every VPN profile NetworkManager knows
(`●` connected, `◐` connecting), select one to connect or disconnect. One tunnel is up at a time.

- **Add a VPN…** imports a WireGuard `.conf` (built into NetworkManager), an OpenVPN `.ovpn` or a Cisco `.pcf`
  (with the NetworkManager plugin) from Downloads, Documents, Desktop or a path; asks for the name and missing
  passwords. **FRITZ!Box (IPsec)** sets up older boxes (FRITZ!OS before 7.50) step by step; newer boxes export a
  WireGuard file. Other types (OpenConnect, L2TP, IKEv2) open `nm-connection-editor`.
- **Manage profiles…** switches autoconnect on or off and removes profiles.
- On the shell: `vpn list`, `vpn status`, `vpn up [NAME]`, `vpn down [NAME]`, `vpn toggle`,
  `vpn import [--dry-run] FILE [NAME]`, `vpn fritzbox`, `vpn autoconnect NAME on|off`, `vpn remove NAME`
  (`vpn --help`).

New VPN profiles never connect on their own. Tunnels that carry all traffic use only their own DNS servers, and a
WireGuard full tunnel also takes IPv6, so neither can leak around it. `PreUp`/`PostUp` hooks in WireGuard files
and OpenVPN scripts are never run.

> [!NOTE]
> New WiFi and VPN profiles are stored system-wide, with their keys readable by root only. Adding one, or storing a
> new password, therefore asks for your login password in a polkit dialog (once per change). Connecting and
> disconnecting need no password.

## Settings

All basic settings live in [`dotfiles.conf`](dotfiles.conf) in the repository root. After editing it, run:

```bash
dotfiles apply      # or: dotfiles edit (opens the file, applies after saving)
```

`dotfiles apply` checks every value (unknown keys and invalid values are reported, nothing is changed then),
renders `templates/*` into `~/.config/dotfiles/`, draws the cursor theme into `~/.icons/dotfiles`, and reloads i3,
Polybar, dunst and tmux. Alacritty, Rofi and fzf pick the change up by themselves, Neovim, GTK programs, Firefox and
open shells on their next start (also the new cursor). Idle times and the keyboard layout are applied immediately.

| Group | Keys |
| --- | --- |
| Colors | `accent` (gruvbox name like `red`, `blue`, `aqua` or `#rrggbb`), `accent_text`, `bg`, `surface`, `overlay`, `fg`, `subtle`, `muted` |
| Fonts | `font` (a Nerd Font), `font_size_terminal`, `font_size_bar`, `font_size_menu`, `font_size_notify`, `font_size_window` |
| Layout | `bar_height`, `border_width`, `gaps`, `terminal_opacity`, `terminal_padding_x`, `terminal_padding_y`, `cursor_style` (`light`, `dark`, `accent`), `cursor_size` |
| Behaviour | `terminal`, `keyboard_layout`, `wallpaper`, `screensaver_after`, `lock_after`, `display_off_after` |

Other commands: `dotfiles check`, `dotfiles get accent`, `dotfiles list`.

The configs include the generated files (`include ~/.config/dotfiles/i3.conf`, `include-file` in Polybar,
`@import` in Rofi and GTK, `import` in Alacritty, `source-file` in tmux, `FZF_DEFAULT_OPTS_FILE` for fzf, a drop-in in
`~/.config/dunst/dunstrc.d/`). Shell scripts read `~/.config/dotfiles/theme.sh`.
To change the design itself, edit the configs or the templates in `templates/`.

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
bluez rfkill NetworkManager libnm libnotify elogind polkit-gnome \
mpv mpv-mpris playerctl brightnessctl \
neomutt fzf ncurses caffeine-ng python3 python3-gobject gtk+3 tmux ffmpeg
```

Optional:
- `NetworkManager-openvpn`, `NetworkManager-vpnc` (OpenVPN and Cisco/FRITZ!Box profiles in the VPN menu),
  `network-manager-applet` (`nm-connection-editor` for other VPN types and WPA-Enterprise)
- `chafa` (sharper album covers in `mpvim`; without it they are drawn with half blocks via `python3-Pillow`)
- `python3-Pillow` also redraws the README pictures (`assets/readme/render.py`)

Minimum versions: i3 4.22, polybar 3.6, picom 12 (uses the `rules` syntax), rofi 1.7, dunst 1.9, scrot 1.7,
bash 5.1 (text objects; 5.3 for the duration capsule and the prompt without subshells), tmux 3.2,
alacritty 0.14 (`[general] import`), fzf 0.66 (`--gutter`), NetworkManager 1.20.

Also needed:
- JetBrainsMono Nerd Font (v3, `md-*` icons; on Void in `nerd-fonts-ttf`)
- No cursor theme: `dotfiles apply` draws its own (with `python3-cairo`, which comes with `python3-gobject`)
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

The script links every file of `config/` into `~/.config/` (file by file, e.g. `~/.config/i3/config`, so your own files in those directories stay), the dotfiles into `~/`, the scripts into `~/.local/bin/` and the `.desktop` launchers into `~/.local/share/applications/` (each only if its program is installed, see step 5). It makes the scripts executable and runs `dotfiles apply` once. Existing files it would replace are moved to `*.bak-<timestamp>`; links to files that were removed from the repository are deleted. It can be run again safely (also after `git pull`, to link new files).

> [!IMPORTANT]
> Everything is linked, not copied: editing the repository or switching git branches changes the running desktop
> (Alacritty reloads its config live, scripts and Rofi pick up changes on their next start).

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

### 5. Launchers

`install.sh` links a launcher only if its program is installed, so Rofi never lists one that fails: the menus of
this repository (Bluetooth, WiFi, Display, VPN) always, the others (`pulsemixer`, `htop`, `neomutt`, Firefox,
Signal and the author's own tools `calculus` and `notice`) only where their program is found (the command of
`Exec=` and `TryExec=`). Run `./install.sh` again after installing or removing a program: it adds or removes the
launcher.

The launchers in `applications/local/` (Aseprite, Command & Conquer Generals, Factorio, World of Warcraft, Sunshine) are
machine-specific and point to install locations under `/home/floppyist/`; for them every absolute path in `Exec=` and
`Path=` must exist as well. Change `Exec=` and `Path=` to your install locations (or put your own launchers there) and
run `./install.sh` again.

## Security notes

- The screen is locked before suspend (`xss-lock --transfer-sleep-lock`), so no content is visible on resume. If `i3lock-color` fails, plain `i3lock` is used; if that fails too, a critical notification says that the screen is **not** locked.
- Text that other people control (song titles from websites, WiFi names, Bluetooth device names, VPN profile names) is sanitized before it reaches Polybar, which would otherwise interpret `%{A:…:}` tags as clickable shell commands.
- The region screenshot overlay holds pointer and keyboard, which would keep `i3lock` from locking. It gives them up
  when logind announces suspend or a lock, and before the screensaver starts.
- System menus never act on typed text that matches no entry (`rofi -no-custom`), so a typo cannot select a random network or display mode.
- WiFi and VPN passwords and keys never appear on a command line, in the environment or in a notification: they go from Rofi's password field to NetworkManager over D-Bus (`wifi-connect` and `vpn` use libnm), and the profiles are stored root-only. Imported VPN files are parsed, never executed.
- The git prompt runs `git status` with `core.fsmonitor=false`, so a repository's own config cannot start a program when you `cd` into it. Control characters in directory names are replaced in the prompt (no escape sequences from a crafted directory name).
- Runtime files (mpv IPC socket, screensaver log/lock, Polybar module outputs) live in private directories under `$XDG_RUNTIME_DIR`, not under predictable names in `/tmp`.
- `dotfiles.conf` values end up in configs that can run commands (i3, Polybar, tmux, shell), so `dotfiles apply` only accepts strict patterns (colors `#rrggbb`, numbers in a range, fonts and paths without quotes or shell characters).
- A command typed with a leading space is not saved in the bash history.

## Troubleshooting

- **WiFi or VPN: "not authorized":** adding a profile needs a polkit agent for the password dialog. i3 starts `polkit-gnome`; check that it is installed and running.
- **WiFi: a network keeps failing with a saved profile:** the menu asks for the password again when NetworkManager rejects the saved one. For other errors, `nmcli connection delete id "<name>"` and connect again.
- **Polybar hides CPU, volume or music:** the bar is full (see [Polybar](#polybar)); `polybar-fit --explain` prints the measured widths.
- **Bluetooth "Failed to power on":** the Intel AX200 (`btusb`) can get stuck after rfkill cycles. Reload the driver with `sudo modprobe -r btusb && sudo modprobe btusb`, or reboot.
- **Idle lock after updating these dotfiles:** `xss-lock` only starts with the session. Log out and back in once (an i3 restart is not enough).
- **Previous Neovim colors:** set `colorscheme = "catppuccin-frappe"` in `config/nvim/lua/plugins/colorscheme.lua`.
- **Colors look like defaults (dunst, Rofi, Alacritty):** the generated files are missing. Run `dotfiles apply`.
- **Old mouse cursor in some programs:** programs load the cursor theme when they start, i3 when it restarts. After
  the first `dotfiles apply` log out and back in once. Programs started without the session environment use
  `~/.icons/default/index.theme`; put `Inherits=dotfiles` there to get the same cursor. `dotfiles apply` leaves a
  `~/.icons/dotfiles` alone that it did not create (it says so); rename that directory.
- **GTK program still light or unchanged:** GTK reads `~/.config/gtk-3.0/` only when a program starts; restart it. Tools like `lxappearance` replace the linked `settings.ini` with their own file, run `./install.sh` again to restore the link (your file is kept as a backup).
