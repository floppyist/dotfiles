# My Dotfiles (Void Linux + i3wm)

A minimalist and functional development environment based on **i3wm**, **Polybar**, and **Neovim** running on **Void Linux**.

## 📁 Components

- **Window Manager:** `i3wm` (with `i3blocks` & `picom`)
- **Terminal:** `Alacritty`
- **Editor:** `Neovim` (LazyVim distribution)
- **Status Bar:** `Polybar` (includes custom Bluetooth & WLAN modules)
- **Notifications:** `Dunst`
- **Application Launcher:** `Rofi`
- **Browser:** `Firefox` (custom `userChrome.css` for a minimal UI)
- **Scripts:** Bluetooth hardware kill-switch and system status helpers

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone <your-repo-url> ~/dotfiles
cd ~/dotfiles
```

### 2. Symlink Configuration Files
Most configurations belong in the `~/.config` directory:
```bash
mkdir -p ~/.config
ln -s ~/dotfiles/config/* ~/.config/
```

### 3. Install Scripts
Scripts should be placed in your local binary path:
```bash
mkdir -p ~/.local/bin
cp ~/dotfiles/scripts/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh
```

> **Note:** Ensure `~/.local/bin` is added to your `$PATH`.

### 4. Firefox `userChrome.css`
Firefox requires a specific path inside your profile folder:
```bash
# Replace <your-profile> with your actual profile name (e.g., xxxxxxxx.default-release)
mkdir -p ~/.mozilla/firefox/<your-profile>/chrome/
ln -s ~/dotfiles/config/firefox/userChrome.css \
  ~/.mozilla/firefox/<your-profile>/chrome/userChrome.css
```

Enable custom styles in Firefox:
- Open `about:config`
- Set `toolkit.legacyUserProfileCustomizations.stylesheets` to `true`

## 🔧 Dependencies (Void Linux)

Required packages:
- `i3-gaps`, `polybar`, `rofi`, `dunst`, `picom`, `alacritty`
- `pipewire`, `wireplumber`, `libspa-bluetooth`
- `bluez`, `rfkill`
- `NetworkManager`, `nm-applet`
- mpv-mpris (if you use mpv)

Example installation:
```bash
sudo xbps-install -S \
  i3-gaps polybar rofi dunst picom alacritty \
  pipewire wireplumber libspa-bluetooth \
  bluez rfkill NetworkManager nm-applet
```

## ⌨️ Custom Keybinds

- **XF86Display / F12:** Bluetooth hardware kill-switch (toggle)
- **Mod + Bluetooth Icon:** Open Rofi Bluetooth menu

## 📝 Notes

- Designed for Void Linux (glibc)
- Minimal, keyboard-driven workflow
- CLI-first, no desktop bloat
