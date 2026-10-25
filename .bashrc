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

# Everything below is for interactive shells only
[[ $- == *i* ]] || return

# ── Shell options ────────────────────────────────────────────────────────────

# No duplicates; a command with a leading space is not saved (useful for secrets)
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend checkwinsize

set -o vi
PROMPT_DIRTRIM=3

# ── Prompt ───────────────────────────────────────────────────────────────────
#
#   ╭─ user@host ~/path [ main *+? ↑1] 󰒓 1 ✗ 127
#   ╰─❯
#
#   *  modified   +  staged   ?  untracked   ↑/↓  ahead/behind upstream
#   󰒓 background jobs   ✗ exit code of the last command (the chevron turns red)

if [[ "$TERM" == linux ]]; then
    # Linux console: 16 colors, no box drawing / Nerd Font glyphs
    _P_MUTED=$'\e[90m'  _P_SUBTLE=$'\e[37m'  _P_PATH=$'\e[97m'
    _P_USER=$'\e[1;35m' _P_HOST=$'\e[1;36m'  _P_ERR=$'\e[1;31m'
    _P_CLEAN=$'\e[32m'  _P_DIRTY=$'\e[33m'   _P_JOBS=$'\e[34m'
    _P_TOP="" _P_BOT="" _P_CHEV=">" _P_BRANCH="" _P_JOB="jobs:"
else
    # 24-bit colors from the desktop palette
    _rgb() { printf '\e[%s38;2;%d;%d;%dm' "$2" "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
    _P_MUTED=$(_rgb 7c6f64)   _P_SUBTLE=$(_rgb a89984)   _P_PATH=$(_rgb ebdbb2)
    _P_USER=$(_rgb d3869b 1\;) _P_HOST=$(_rgb 8ec07c 1\;) _P_ERR=$(_rgb fb4934 1\;)
    _P_CLEAN=$(_rgb b8bb26)   _P_DIRTY=$(_rgb fe8019)    _P_JOBS=$(_rgb 83a598)
    _P_TOP="╭─ " _P_BOT="╰─" _P_CHEV="❯" _P_BRANCH=" " _P_JOB="󰒓 "
    unset -f _rgb
fi
_P_RESET=$'\e[0m'

# Git segment. Runs at prompt time through \$(...) in PS1: its output is NOT expanded
# again, so branch names like "$(cmd)" (valid in git) are printed, never executed.
# \001/\002 mark the color codes as zero-width for readline.
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

_prompt() {
    local rc=$? jobs=0 _ user='\u' ucolor=$_P_USER chev=$_P_SUBTLE extra=""
    for _ in $(jobs -p); do (( jobs++ )); done
    (( EUID == 0 )) && { user="ROOT"; ucolor=$_P_ERR; }
    (( jobs > 0 )) && extra+=" \[$_P_JOBS\]$_P_JOB$jobs"
    (( rc != 0 )) && { extra+=" \[$_P_ERR\]✗ $rc"; chev=$_P_ERR; }

    PS1="\[$_P_MUTED\]$_P_TOP\[$ucolor\]$user\[$_P_MUTED\]@\[$_P_HOST\]\h \[$_P_PATH\]\w\$(_prompt_git)$extra\[$_P_RESET\]\n"
    PS1+="\[$_P_MUTED\]$_P_BOT\[$chev\]$_P_CHEV \[$_P_RESET\]"
}
PROMPT_COMMAND=_prompt

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

[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash
