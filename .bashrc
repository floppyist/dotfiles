# ~/.bashrc

# ── Environment (all shells) ─────────────────────────────────────────────────

# Prepend a directory to PATH only if it is not there yet (avoids duplicates in nested shells)
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.opencode/bin"
export PATH

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

export CALCULUS_STATE=~/.cache/calculus
export PI_CODING_AGENT_DIR="$HOME/.local/share/pi"
export PI_TELEMETRY=0
# Editor for git, crontab, ... and for `v` in the shell's normal mode (edit the line in vim)
export EDITOR="${EDITOR:-nvim}" VISUAL="${VISUAL:-${EDITOR:-nvim}}"
# fzf colors and layout from dotfiles.conf (generated; fzf reads the file on every start)
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/fzfrc" ]] &&
    export FZF_DEFAULT_OPTS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/fzfrc"

# Everything below is for interactive shells only
[[ $- == *i* ]] || return

# ── Shell options ────────────────────────────────────────────────────────────

# No duplicates; a command with a leading space is not saved (useful for secrets)
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

# Vi mode: readline's own (nothing runs per keystroke) plus the text objects from
# ~/.config/bash/vim.bash (ciw, da", yi( ...). Readline settings: ~/.inputrc.
set -o vi
# shellcheck source=/dev/null
[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/bash/vim.bash" ]] && . "${XDG_CONFIG_HOME:-$HOME/.config}/bash/vim.bash"
PROMPT_DIRTRIM=3

# ── Prompt ───────────────────────────────────────────────────────────────────
#
#   ╭─ user@host ~/path [ main *+? ↑1] 󰒓 1 ✗ 127
#   ╰─❯                 ❯ insert mode (bar cursor), ❮ in the accent: normal mode (block cursor)
#
#   *  modified   +  staged   ?  untracked   ↑/↓  ahead/behind upstream
#   󰒓 background jobs   ✗ exit code of the last command (the chevron turns red)
#   Colors come from dotfiles.conf (~/.config/dotfiles/theme.sh).

if [[ "$TERM" == linux ]]; then
    # Linux console: 16 colors, no box drawing / Nerd Font glyphs, no cursor shapes
    _P_MUTED=$'\e[90m'  _P_SUBTLE=$'\e[37m'  _P_PATH=$'\e[97m'
    _P_USER=$'\e[1;35m' _P_HOST=$'\e[1;36m'  _P_ERR=$'\e[1;31m'
    _P_CLEAN=$'\e[32m'  _P_DIRTY=$'\e[33m'   _P_JOBS=$'\e[34m'   _P_ACCENT=$'\e[1;31m'
    _P_LABEL=$'\e[31m'
    _P_TOP="" _P_BOT="" _P_CHEV=">" _P_CHEV_CMD="<" _P_BRANCH="" _P_JOB="jobs:"
    _P_CUR_INS="" _P_CUR_CMD=""
else
    DF_MUTED="#7c6f64" DF_SUBTLE="#a89984" DF_FG="#ebdbb2" DF_PURPLE_HI="#d3869b" DF_AQUA_HI="#8ec07c"
    DF_RED_HI="#fb4934" DF_GREEN_HI="#b8bb26" DF_ORANGE_HI="#fe8019" DF_BLUE_HI="#83a598"
    DF_ACCENT_TEXT="#fb4934"
    # shellcheck source=/dev/null
    . "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
    # 24-bit color escape from #rrggbb; $2: extra SGR attributes (e.g. "1;" for bold)
    _rgb() { local c=${1#\#}; printf '\e[%s38;2;%d;%d;%dm' "$2" "0x${c:0:2}" "0x${c:2:2}" "0x${c:4:2}"; }
    _P_MUTED=$(_rgb "$DF_MUTED")         _P_SUBTLE=$(_rgb "$DF_SUBTLE")      _P_PATH=$(_rgb "$DF_FG")
    _P_USER=$(_rgb "$DF_PURPLE_HI" '1;') _P_HOST=$(_rgb "$DF_AQUA_HI" '1;')  _P_ERR=$(_rgb "$DF_RED_HI" '1;')
    _P_CLEAN=$(_rgb "$DF_GREEN_HI")      _P_DIRTY=$(_rgb "$DF_ORANGE_HI")    _P_JOBS=$(_rgb "$DF_BLUE_HI")
    _P_ACCENT=$(_rgb "$DF_ACCENT_TEXT" '1;') _P_LABEL=$(_rgb "$DF_ACCENT_TEXT")
    _P_TOP="╭─ " _P_BOT="╰─" _P_CHEV="❯" _P_CHEV_CMD="❮" _P_BRANCH=$'\xee\x82\xa0 ' _P_JOB="󰒓 "
    # Cursor shape (DECSCUSR, as text for readline): bar in insert mode, block in normal mode
    _P_CUR_INS='\e[6 q' _P_CUR_CMD='\e[2 q'
    unset -f _rgb
fi
_P_RESET=$'\e[0m'

# Git segment: " [ main *+?]". The branch glyph (pl-branch U+E0A0) is written as bytes:
# editors and tools tend to drop Private Use characters. \001/\002 mark the color codes as zero-width for readline.
_prompt_git() {
    local out head files line branch ahead="" behind="" staged="" modified="" untracked="" color sym=""
    # core.fsmonitor=false: a repository's own config could otherwise make `git status`
    # run a program of its choice (e.g. in an unpacked archive you just cd'ed into)
    out=$(git -c core.fsmonitor=false status --porcelain=v1 --branch 2>/dev/null) || return 0
    head=${out%%$'\n'*}
    head=${head#'## '}
    files=""
    [[ "$out" == *$'\n'* ]] && files=${out#*$'\n'}

    case "$head" in
        "No commits yet on "*) branch=${head#No commits yet on } ;;
        "Initial commit on "*) branch=${head#Initial commit on } ;;
        "HEAD (no branch)"*)   branch=$(git rev-parse --short HEAD 2>/dev/null) ;;
        *)                     branch=${head%%...*}; branch=${branch%% *} ;;
    esac
    [[ "$head" =~ ahead\ ([0-9]+) ]] && ahead=" ↑${BASH_REMATCH[1]}"
    [[ "$head" =~ behind\ ([0-9]+) ]] && behind=" ↓${BASH_REMATCH[1]}"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ ${line:0:2} == "??" ]]; then untracked="?"; continue; fi
        [[ ${line:0:1} == [MADRCU] ]] && staged="+"
        [[ ${line:1:1} == [MDU] ]] && modified="*"
    done <<< "$files"

    sym="$modified$staged$untracked"
    color=$_P_CLEAN
    [[ -n "$sym" ]] && color=$_P_DIRTY

    printf ' \001%s\002[\001%s\002%s%s%s%s%s\001%s\002]\001%s\002' \
        "$_P_MUTED" "$color" "$_P_BRANCH" "$branch" "${sym:+ $sym}" "$ahead" "$behind" "$_P_MUTED" "$_P_RESET"
}

# The second prompt line is readline's mode string: readline puts it in front of the last
# prompt line and swaps it itself when the mode changes (no shell code runs for that).
# "╰─❯" in insert mode, "╰─❮" in the accent in normal mode, each with its cursor shape.
# $1: chevron color; empty for continuation lines (cursor shape only). Readline takes the
# escapes as text (\e) and the color codes between \1 and \2 (zero width).
_prompt_mode() {
    local esc='\e' ins cmd
    local muted=${_P_MUTED//$'\e'/"$esc"} chev=${1//$'\e'/"$esc"} accent=${_P_ACCENT//$'\e'/"$esc"}
    if [[ -n $1 ]]; then
        ins="\\1$muted\\2$_P_BOT\\1$chev\\2$_P_CHEV\\1\\e[0m$_P_CUR_INS\\2"
        cmd="\\1$muted\\2$_P_BOT\\1$accent\\2$_P_CHEV_CMD\\1\\e[0m$_P_CUR_CMD\\2"
    else
        ins="\\1$_P_CUR_INS\\2" cmd="\\1$_P_CUR_CMD\\2"
    fi
    bind "set vi-ins-mode-string \"$ins\""
    bind "set vi-cmd-mode-string \"$cmd\""
    bind "set emacs-mode-string \"$ins\""
    _P_MODE=$1
}
bind 'set show-mode-in-prompt on'

# The git segment is computed once per prompt into _P_GIT; PS1 only references the
# variable. Expansions in PS1 are not expanded again, so branch names like "$(cmd)"
# (valid in git) are printed, never executed.
_prompt() {
    local rc=$? jobs=0 _ user='\u' ucolor=$_P_USER extra="" chev=$_P_SUBTLE
    for _ in $(jobs -p); do (( jobs++ )); done
    (( EUID == 0 )) && { user="ROOT"; ucolor=$_P_ERR; }
    (( jobs > 0 )) && extra+=" \[$_P_JOBS\]$_P_JOB$jobs"
    (( rc != 0 )) && { extra+=" \[$_P_ERR\]✗ $rc"; chev=$_P_ERR; }
    _P_GIT=$(_prompt_git)
    [[ $chev == "${_P_MODE-}" ]] || _prompt_mode "$chev"

    # line 2 = the mode string (╰─❯) + this space
    PS1="\[$_P_MUTED\]$_P_TOP\[$ucolor\]$user\[$_P_MUTED\]@\[$_P_HOST\]\h \[$_P_PATH\]\w\${_P_GIT}$extra\[$_P_RESET\]\n "
}
PROMPT_COMMAND=_prompt

# Continuation lines (open quotes, for ... do): readline would put "╰─❯" in front of them,
# too. Bash 5.3 runs ${ cmd; } in the shell itself, so PS2 switches the mode string to the
# cursor shape only; the next _prompt switches it back.
if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503 )); then
    PS2='${ _prompt_mode ""; }'"\[$_P_MUTED\]  · \[$_P_RESET\]"
else
    PS2=" "
fi

# ── Aliases ──────────────────────────────────────────────────────────────────

alias ls='ls --color=auto'
alias la='ls -la --color=auto'
alias ll='ls -l --color=auto'
# Real grep: aliasing it to rg breaks grep flags (rg -r is --replace, -E is --encoding)
alias grep='grep --color=auto'
alias vim='nvim'
alias mutt='neomutt'
alias mpv='mpvim'
alias mixer='pulsemixer'
alias calc='calculus'
alias cb='xclip -selection clipboard'

# ── Tools ────────────────────────────────────────────────────────────────────

# fzf key bindings: Ctrl+r history, Ctrl+t files, Alt+c cd (insert and normal mode).
# Bash clears the prompt's last line before a key binding runs, so fzf opens in place of
# "╰─❯" and its input line continues the prompt (label in the accent, like rofi's "apps ❯"):
#   ╭─ user@host ~/path
#   ╰─ history ❯ query                                          4/120
_fzf_prompt() {
    printf -- "--prompt='%s%s%s%s %s%s '" "$_P_MUTED" "${_P_BOT:+$_P_BOT }" "$_P_LABEL" "$1" "$_P_SUBTLE" "$_P_CHEV"
}
FZF_CTRL_R_OPTS=$(_fzf_prompt history)
FZF_CTRL_T_OPTS=$(_fzf_prompt files)
FZF_ALT_C_OPTS=$(_fzf_prompt cd)
unset -f _fzf_prompt
# shellcheck source=/dev/null
[[ -f /usr/share/fzf/key-bindings.bash ]] && . /usr/share/fzf/key-bindings.bash

# Alt+c: fzf's own binding types `__fzf_cd__` into the command line and runs it from there,
# so that text stays visible above fzf. Here it is a bind -x widget like Ctrl+r and Ctrl+t
# (fzf opens in place of "╰─❯"), then an empty accept-line draws a fresh prompt in the new
# directory and the line that was typed comes back.
if declare -F __fzf_cd__ >/dev/null; then
    _fzf_cd_widget() {
        local cmd
        _FZF_LINE=$READLINE_LINE _FZF_POINT=$READLINE_POINT
        READLINE_LINE="" READLINE_POINT=0
        # prints "builtin cd -- <dir quoted with %q>"
        cmd=$(__fzf_cd__) && eval "$cmd"
    }
    _fzf_cd_restore() {
        READLINE_LINE=${_FZF_LINE-} READLINE_POINT=${_FZF_POINT:-0}
        unset _FZF_LINE _FZF_POINT
    }
    for _m in vi-insert vi-command emacs-standard; do
        bind -m "$_m" -x '"\C-x\C-o": _fzf_cd_widget'
        bind -m "$_m" -x '"\C-x\C-l": _fzf_cd_restore'
        bind -m "$_m" '"\ec": "\C-x\C-o\C-m\C-x\C-l"'
    done
    unset _m
fi
