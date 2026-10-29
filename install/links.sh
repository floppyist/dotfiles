# shellcheck shell=bash
# install/links.sh  ·  links the repository into $HOME, file by file.
# - ~/.config/i3/config -> config/i3/config: other files in those directories (your own, state
#   that programs write) stay where they are. Directories that older versions linked as a whole
#   (~/.config/i3 -> config/i3) become real directories.
# - A file that would be replaced is moved to *.bak-<timestamp>; links into this repository
#   (e.g. to a file's old location) are simply replaced.
# - Desktop launchers only where their program is installed; links of removed ones are deleted.
# - Links into this repository whose file is gone (renamed or deleted here) are removed.
# - Idempotent: running it again changes nothing that is already correct.
# LINKS_DRY=1: change nothing, only print what would happen (LINKS_TODO, LINKS_BACKUPS).

REAL=$(cd "$DOTFILES" && pwd -P)   # physical path, to recognise links into the repository
LINKS_DRY=0

# true if $1 is a link that points into this repository (also if its target is gone)
into_repo() {
    [[ -L "$1" ]] || return 1
    local target
    target="$(readlink -m "$1")"
    [[ "$target" == "$REAL" || "$target" == "$REAL"/* ]]
}

backup() {
    # Never move a file of the repository itself (reachable through a linked directory)
    if [[ ! -L "$1" && "$(readlink -m "$1")" == "$REAL"/* ]]; then
        echo "$1 is a file of this repository, not moving it" >&2
        return 1
    fi
    if (( LINKS_DRY )); then
        LINKS_BACKUPS+=("$1")
        return 0
    fi
    mv "$1" "$1.bak-$STAMP" || return 1
    echo "backup  $1 -> $1.bak-$STAMP"
}

# Make $1 a real directory. Below ~/.config, a link to a directory of this repository is
# replaced (it was linked as a whole before), anything else in the way is moved to a backup.
# ~/.config itself and directories outside it are only created (they may be links on purpose).
ensure_dir() {
    local dir=$1
    [[ -d "$dir" && ! -L "$dir" ]] && return 0
    if [[ "$dir" != "$CONFIG"/* ]]; then
        (( LINKS_DRY )) || mkdir -p "$dir"
        return
    fi
    ensure_dir "$(dirname "$dir")" || return 1
    if into_repo "$dir"; then
        (( LINKS_DRY )) && return 0
        rm "$dir" || return 1
        echo "unlink  $dir (now linked file by file)"
    elif [[ -e "$dir" || -L "$dir" ]]; then
        backup "$dir" || return 1
    fi
    (( LINKS_DRY )) || mkdir "$dir"
}

link() {
    local src=$1 dst=$2
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        return 0
    fi
    (( LINKS_TODO++ ))
    ensure_dir "$(dirname "$dst")" || return 1
    if into_repo "$dst"; then
        (( LINKS_DRY )) || rm "$dst" || return 1
    elif [[ -e "$dst" || -L "$dst" ]]; then
        backup "$dst" || return 1
    fi
    (( LINKS_DRY )) && return 0
    ln -s "$src" "$dst" || return 1
    echo "link    $dst -> $src"
}

# True if the program of the launcher $1 is installed: TryExec= and the command of Exec= are
# found, every absolute path in Exec= (e.g. the .exe for wine) and Path= exists. Sets MISSING.
launcher_ok() {
    local line section="" exec="" try="" path="" w words=()
    while IFS= read -r line; do
        if [[ "$line" == \[*\] ]]; then section=$line; continue; fi
        [[ "$section" == "[Desktop Entry]" ]] || continue
        case "$line" in
            Exec=*)    exec=${line#Exec=} ;;
            TryExec=*) try=${line#TryExec=} ;;
            Path=*)    path=${line#Path=} ;;
        esac
    done < "$1"
    # split like the desktop entry spec (double quotes); xargs never runs the words
    mapfile -t words < <(printf '%s\n' "$exec" | xargs -n1 printf '%s\n' 2>/dev/null)
    MISSING=${try:-${words[0]:-Exec=}}
    [[ -z "$try" ]] || command -v "$try" >/dev/null || return 1
    (( ${#words[@]} )) && command -v "${words[0]}" >/dev/null || { MISSING=${words[0]:-Exec=}; return 1; }
    for w in "${words[@]:1}" "$path"; do
        if [[ "$w" == /* && ! -e "$w" ]]; then MISSING=$w; return 1; fi
    done
    return 0
}

# Remove links into this repository whose target no longer exists. $1: directory, $2: depth
prune() {
    local l
    [[ -d "$1" ]] || return 0
    while IFS= read -r -d '' l; do
        if [[ ! -e "$l" ]] && into_repo "$l"; then
            (( LINKS_DRY )) && continue
            rm "$l"
            echo "remove  $l (no longer in the repository)"
        fi
    done < <(find "$1/" -maxdepth "$2" -type l -print0)
}

# Files below config/: tracked and new ones, not the gitignored ones (generated files, backups)
config_files() {
    if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$DOTFILES" -c core.fsmonitor=false ls-files -z --cached --others --exclude-standard -- config
    else
        (cd "$DOTFILES" && find config -type f ! -path 'config/dunst/dunstrc.d/*' -print0)
    fi
}

links_run() {
    local rel src dst name dir
    LINKS_TODO=0 LINKS_BACKUPS=()

    # ~/.config/<name>/<file>. config/udev belongs to /etc (the laptop module installs it).
    while IFS= read -r -d '' rel; do
        [[ -f "$DOTFILES/$rel" ]] || continue   # deleted, but not committed yet
        [[ "$rel" == config/udev/* ]] && continue
        link "$DOTFILES/$rel" "$CONFIG/${rel#config/}" || return 1
    done < <(config_files | sort -z)

    # Dotfiles in $HOME
    for name in .bashrc .inputrc .xinitrc .Xresources; do
        link "$DOTFILES/$name" "$HOME/$name" || return 1
    done

    # Scripts -> ~/.local/bin (files only: scripts/lib holds what they source)
    for src in "$DOTFILES"/scripts/*; do
        [[ -f $src ]] || continue
        link "$src" "$HOME/.local/bin/$(basename "$src")" || return 1
    done

    # Desktop entries -> ~/.local/share/applications, each only where its program is installed,
    # so rofi never shows a launcher that fails. The session's PATH (.xinitrc) starts with
    # ~/.local/bin: the menus of this repository and terminal.sh are found there (linked above),
    # also when this shell's PATH does not have it yet.
    local PATH="$HOME/.local/bin:$PATH"
    for src in "$DOTFILES"/applications/*.desktop "$DOTFILES"/applications/local/*.desktop; do
        [[ -f "$src" ]] || continue
        dst="$HOME/.local/share/applications/$(basename "$src")"
        if launcher_ok "$src"; then
            link "$src" "$dst" || return 1
        elif into_repo "$dst"; then
            (( LINKS_DRY )) && continue
            rm "$dst"
            echo "remove  $dst (not installed: $MISSING)"
        elif (( ! LINKS_DRY )); then
            echo "skip    $dst (not installed: $MISSING)"
        fi
    done

    # Links to files that were renamed or removed here
    prune "$CONFIG" 1
    for dir in "$DOTFILES"/config/*/; do
        prune "$CONFIG/$(basename "$dir")" 10
    done
    prune "$HOME" 1
    prune "$HOME/.local/bin" 1
    prune "$HOME/.local/share/applications" 1

    (( LINKS_DRY )) && return 0

    # Executable bits (git tracks them, this is for copies without git)
    local f
    for f in "$DOTFILES"/scripts/* "$DOTFILES"/config/polybar/launch.sh; do
        [[ -f $f ]] && chmod +x "$f"
    done

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
    fi
    return 0
}
