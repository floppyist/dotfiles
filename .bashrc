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

# ── Prompt ───────────────────────────────────────────────────────────────────
#
#   ▌ user@host  ~/workspace/dotfiles   main *? ↑1   ✗ 130 INT   󰒓  1   󰔛  12s
#   ▌ _
#
# The same building blocks as polybar, tmux and rofi:
#   ▌ + surface    user@host, like rofi's selected row; the bar runs on into line 2
#   accent block   the current directory (like the focused workspace / tmux window),
#                  parents regular, the directory itself bold, trimmed to 3 levels
#   capsules       surface, colored icon, text in fg (polybar style):
#                  git (icon green = clean, orange = dirty; * modified, + staged,
#                  ? untracked, ↑/↓ ahead/behind), ✗ exit code (+ signal), 󰒓 jobs,
#                  󰔛 duration (from 2 s, bash 5.3+)
#   line 2         readline's mode string: ▌ accent = insert (bar cursor),
#                  ▌ yellow = normal mode (block cursor, yellow like the mode badges),
#                  ▌ muted = continuation line (open quote, for ... do)
#   root           ROOT@host as a red block instead of user@host
#   Colors come from dotfiles.conf (~/.config/dotfiles/theme.sh).
#
# Speed: PS1 is set once and only references variables. _prompt fills them without a
# subshell (bash 5.3 ${ ...; }); `git status` runs only inside a repository, found by a
# pure-bash walk up to .git. Nothing runs per keystroke.

if [[ "$TERM" == linux ]]; then
    # Linux console: 16 colors, no Nerd Font glyphs, no cursor shapes
    _P_FG=$'\e[97m'       _P_SUBTLE=$'\e[37m'  _P_MUTED=$'\e[90m'   _P_BAR=$'\e[31m'
    _P_NORMAL=$'\e[33m'   _P_LABEL=$'\e[1;97m' _P_CLEAN=$'\e[32m'   _P_DIRTY=$'\e[33m'
    _P_ERR=$'\e[31m'      _P_JOBC=$'\e[34m'    _P_TIMEC=$'\e[36m'
    _P_SURF=$'\e[100m'    _P_PATHB=$'\e[30;41m' _P_ROOTB=$'\e[1;97;41m'
    _P_CHEV=">" _P_CHEV1="" _P_ELL="..." _P_BRANCH="" _P_X="x" _P_JOB="jobs " _P_TIME=""
    _P_CUR_INS="" _P_CUR_CMD=""
else
    DF_MUTED="#7c6f64" DF_SUBTLE="#a89984" DF_FG="#ebdbb2" DF_AQUA_HI="#8ec07c" DF_RED_HI="#fb4934"
    DF_GREEN_HI="#b8bb26" DF_ORANGE_HI="#fe8019" DF_BLUE_HI="#83a598" DF_YELLOW_HI="#fabd2f"
    DF_ACCENT="#cc241d" DF_SURFACE="#252a2a" DF_ON_ACCENT="#191c1c"
    # shellcheck source=/dev/null
    . "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/theme.sh" 2>/dev/null
    # 24-bit color escapes from #rrggbb: _fg (foreground), _bg (background)
    _fg() { local c=${1#\#}; printf '\e[38;2;%d;%d;%dm' "0x${c:0:2}" "0x${c:2:2}" "0x${c:4:2}"; }
    _bg() { local c=${1#\#}; printf '\e[48;2;%d;%d;%dm' "0x${c:0:2}" "0x${c:2:2}" "0x${c:4:2}"; }
    _P_FG=$(_fg "$DF_FG")              _P_SUBTLE=$(_fg "$DF_SUBTLE")   _P_MUTED=$(_fg "$DF_MUTED")
    _P_BAR=$(_fg "$DF_ACCENT")         _P_NORMAL=$(_fg "$DF_YELLOW_HI") _P_LABEL=$'\e[1m'$_P_FG
    _P_CLEAN=$(_fg "$DF_GREEN_HI")     _P_DIRTY=$(_fg "$DF_ORANGE_HI") _P_ERR=$(_fg "$DF_RED_HI")
    _P_JOBC=$(_fg "$DF_BLUE_HI")       _P_TIMEC=$(_fg "$DF_AQUA_HI")
    _P_SURF=$(_bg "$DF_SURFACE")
    _P_PATHB=$(_fg "$DF_ON_ACCENT")$(_bg "$DF_ACCENT")
    _P_ROOTB=$'\e[1m'$(_fg "$DF_ON_ACCENT")$(_bg "$DF_RED_HI")
    # Glyphs; Private Use characters as bytes (editors and tools tend to drop them):
    # pl-branch U+E0A0, md-cog U+F0493, md-timer_outline U+F051B.
    _P_CHEV="▌" _P_CHEV1="▌" _P_ELL="…" _P_BRANCH=$'\xee\x82\xa0 ' _P_X="✗"
    _P_JOB=$'\xf3\xb0\x92\x93 ' _P_TIME=$'\xf3\xb0\x94\x9b '
    # Cursor shape (DECSCUSR, as text for readline): bar in insert mode, block in normal mode
    _P_CUR_INS='\e[6 q' _P_CUR_CMD='\e[2 q'
    unset -f _fg _bg
fi
_P_RESET=$'\e[0m' _P_BOLD=$'\e[1m' _P_NOBOLD=$'\e[22m'

# Prompt text that travels through a variable marks its color codes with \001 \002
# (zero width for readline). _pc wraps codes: _pc "$_P_FG" -> \001<code>\002
_pc() { printf -v "$1" '\001%s\002' "$2"; }
_pc _p_fg "$_P_FG"; _pc _p_subtle "$_P_SUBTLE"; _pc _p_muted "$_P_MUTED"; _pc _p_bar "$_P_BAR"
_pc _p_surf "$_P_SURF"; _pc _p_pathb "$_P_PATHB"; _pc _p_rootb "$_P_ROOTB"; _pc _p_rst "$_P_RESET"
_pc _p_err "$_P_ERR"; _pc _p_jobc "$_P_JOBC"; _pc _p_timec "$_P_TIMEC"; _pc _p_dirty "$_P_DIRTY"
_pc _p_clean "$_P_CLEAN"; _pc _p_bold "$_P_BOLD"; _pc _p_nobold "$_P_NOBOLD"
unset -f _pc

# user@host, built once: accent bar + surface (rofi's selected row); root gets a red block
if (( EUID == 0 )); then
    _P_HOSTSEG="$_p_rootb ROOT@${HOSTNAME%%.*} $_p_rst "
else
    _P_HOSTSEG="$_p_surf$_p_bar$_P_CHEV1 $_p_fg${USER:-$(id -un)}$_p_muted@$_p_subtle${HOSTNAME%%.*} $_p_rst "
fi

# Current directory block: "~/.../b/c/d" with the last directory bold. Control characters
# in directory names are replaced, so a name cannot send escape sequences to the terminal.
_prompt_path() {
    local p=$PWD dir base
    case $p in
        "$HOME")   p="~" ;;
        "$HOME"/*) p="~${p#"$HOME"}" ;;
    esac
    p=${p//[[:cntrl:]]/?}
    [[ $p =~ ^(~?)/.+(/[^/]+/[^/]+/[^/]+)$ ]] && p="${BASH_REMATCH[1]}/$_P_ELL${BASH_REMATCH[2]}"
    if [[ $p == / || $p != */* ]]; then dir="" base=$p
    else dir=${p%/*}/ base=${p##*/}; fi
    _P_PATH="$_p_pathb $dir$_p_bold$base $_p_rst"
}

# Git capsule: " main *? ↑1". Sets _P_GIT without a subshell.
_prompt_git() {
    local d=$PWD out head files branch ahead="" sym="" color=$_p_clean
    _P_GIT=""
    # pure-bash look for a repository: outside of one no process is started
    if [[ -z ${GIT_DIR-} ]]; then
        while [[ -n $d && ! -e $d/.git ]]; do d=${d%/*}; done
        [[ -n $d ]] || return 0
    fi
    # core.fsmonitor=false: a repository's own config could otherwise make `git status`
    # run a program of its choice (e.g. in an unpacked archive you just cd'ed into)
    out=$(git -c core.fsmonitor=false --no-optional-locks status --porcelain=v1 --branch 2>/dev/null) || return 0
    head=${out%%$'\n'*}
    head=${head#'## '}
    files=""
    [[ "$out" == *$'\n'* ]] && files=$'\n'${out#*$'\n'}

    case "$head" in
        "No commits yet on "*) branch=${head#No commits yet on } ;;
        "Initial commit on "*) branch=${head#Initial commit on } ;;
        "HEAD (no branch)"*)   branch=$(git rev-parse --short HEAD 2>/dev/null) ;;
        *)                     branch=${head%%...*}; branch=${branch%% *} ;;
    esac
    [[ "$head" =~ ahead\ ([0-9]+) ]] && ahead+=" ↑${BASH_REMATCH[1]}"
    [[ "$head" =~ behind\ ([0-9]+) ]] && ahead+=" ↓${BASH_REMATCH[1]}"

    [[ $files == *$'\n'?[MDU]* ]]  && sym+="*"
    [[ $files == *$'\n'[MADRCU]* ]] && sym+="+"
    [[ $files == *$'\n??'* ]]      && sym+="?"
    [[ -n $sym ]] && { color=$_p_dirty sym=" $_p_dirty$sym"; }

    _P_GIT=" $_p_surf $color$_P_BRANCH$_p_fg$branch$sym${ahead:+$_p_subtle$ahead} $_p_rst"
}

# The second prompt line is readline's mode string: readline puts it in front of the last
# prompt line and swaps it itself when the mode changes (no shell code runs for that).
# $1: "on" = accent bar (first input line), "cont" = muted bar (continuation lines);
# normal mode is always the yellow bar. Does nothing if $1 is already set (bind is not free). Readline takes the escapes as text (\e) and the
# color codes between \1 and \2 (zero width).
_prompt_mode() {
    [[ $1 == "${_P_MODE-}" ]] && return
    local esc='\e' ins cmd
    ins=${_P_BAR//$'\e'/"$esc"}
    [[ $1 == cont ]] && ins=${_P_MUTED//$'\e'/"$esc"}
    ins="\\1$ins\\2$_P_CHEV\\1\\e[0m$_P_CUR_INS\\2"
    cmd="\\1${_P_NORMAL//$'\e'/"$esc"}\\2$_P_CHEV\\1\\e[0m$_P_CUR_CMD\\2"
    bind "set vi-ins-mode-string \"$ins\""
    bind "set vi-cmd-mode-string \"$cmd\""
    bind "set emacs-mode-string \"$ins\""
    _P_MODE=$1
}
bind 'set show-mode-in-prompt on'

# bash 5.3: ${ cmd; } runs in the shell itself (no fork). PS0 stamps the start of a command
# (for the duration capsule), _P_JOBS_CMD lists jobs without a subshell.
if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503 )); then
    PS0='${ _P_T0=${EPOCHREALTIME//[!0-9]/}; }'
    _P_JOBS_CMD='j=${ jobs -p; }'
else
    _P_JOBS_CMD='j=$(jobs -p)'
fi

# PROMPT_COMMAND: fills the variables PS1 references. Expansions in PS1 are not expanded
# again, so branch or directory names like "$(cmd)" are printed, never executed.
_prompt() {
    local rc=$? j="" n=0 t d sig=""
    eval "$_P_JOBS_CMD"
    [[ -n $j ]] && { j=${j//[!$'\n']/}; n=$(( ${#j} + 1 )); }
    _prompt_mode on
    _prompt_path
    _prompt_git
    _P_TAIL=$_P_GIT
    if (( rc != 0 )); then
        # 128 + n: killed by signal n (130 = Ctrl+C)
        (( rc > 128 && rc <= 192 )) && sig=$(kill -l $(( rc - 128 )) 2>/dev/null) && sig=" $sig"
        _P_TAIL+=" $_p_surf$_p_err $_P_X $rc$sig $_p_rst"
    fi
    (( n > 0 )) && _P_TAIL+=" $_p_surf$_p_jobc $_P_JOB$_p_fg$n $_p_rst"
    if [[ ${_P_T0-} =~ ^[0-9]+$ ]]; then
        t=${EPOCHREALTIME//[!0-9]/}
        d=$(( (t - _P_T0) / 1000000 ))
        if (( d >= 3600 )); then   t="$(( d / 3600 ))h $(( d % 3600 / 60 ))m"
        elif (( d >= 60 )); then   t="$(( d / 60 ))m $(( d % 60 ))s"
        else                       t="${d}s"; fi
        (( d >= 2 )) && _P_TAIL+=" $_p_surf$_p_timec $_P_TIME$_p_fg$t $_p_rst"
    fi
    unset _P_T0
}
PROMPT_COMMAND=_prompt

# Line 1 = the blocks; line 2 = the mode string (▌) + this space
PS1='${_P_HOSTSEG}${_P_PATH}${_P_TAIL}\n '

# Continuation lines: muted bar (bash 5.3 switches the mode string from PS2 itself; the
# next _prompt switches it back), so the text lines up with the first input line.
if (( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 503 )); then
    PS2='${ _prompt_mode cont; } '
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
# "▌" and its input line continues the prompt (bar + label in the accent, like rofi's "apps"):
#   user@host ~/path
#   ▌ history query                                            4/120
_fzf_prompt() {
    printf -- "--prompt='%s%s %s%s%s '" "$_P_BAR" "$_P_CHEV" "$_P_LABEL" "$1" "$_P_RESET"
}
FZF_CTRL_R_OPTS=$(_fzf_prompt history)
FZF_CTRL_T_OPTS=$(_fzf_prompt files)
FZF_ALT_C_OPTS=$(_fzf_prompt cd)
unset -f _fzf_prompt
# shellcheck source=/dev/null
[[ -f /usr/share/fzf/key-bindings.bash ]] && . /usr/share/fzf/key-bindings.bash

# Alt+c: fzf's own binding types `__fzf_cd__` into the command line and runs it from there,
# so that text stays visible above fzf. Here it is a bind -x widget like Ctrl+r and Ctrl+t
# (fzf opens in place of "▌"), then an empty accept-line draws a fresh prompt in the new
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
