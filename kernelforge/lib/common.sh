# shellcheck shell=bash
# kernelforge/lib/common.sh  ·  messages, log, privileges, cleanup.
#
# Messages: plain text on a terminal. With KF_PROTOCOL=1 (the dotfiles installer) the progress
# goes out as "@@" lines (install/lib.sh): @@detail, @@progress, @@note, @@warn.

KF_PROTOCOL=${KF_PROTOCOL:-0}
KF_NONINTERACTIVE=${KF_NONINTERACTIVE:-0}
KF_SYSROOT=${KF_SYSROOT:-}          # tests only: /boot and /lib/modules below this directory
DRY_RUN=${DRY_RUN:-0}
LOGFILE=""
TMP_DIRS=()                         # removed on exit
ROLLBACK=()                         # system paths this run created: removed again on failure

if [[ -t 1 && -z ${NO_COLOR-} && ${TERM-dumb} != dumb && $KF_PROTOCOL != 1 ]]; then
    C_B=$'\e[1m' C_G=$'\e[32m' C_Y=$'\e[33m' C_R=$'\e[31m' C_D=$'\e[2m' C_N=$'\e[0m'
else
    C_B="" C_G="" C_Y="" C_R="" C_D="" C_N=""
fi

# Untrusted text (command line, device names) never reaches the terminal as escape sequences
clean() { printf '%s' "${1//[[:cntrl:]]/ }"; }

log_file() { [[ -n $LOGFILE ]] && printf '%s\n' "$*" >> "$LOGFILE"; return 0; }

say()  { printf '%s\n' "$*"; log_file "$*"; }
info() { printf '  %s\n' "$*"; log_file "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_G" "$C_N" "$*"; log_file "OK  $*"; }
warn() {
    if (( KF_PROTOCOL )); then printf '@@warn %s\n' "$*"; else printf '%s! %s%s\n' "$C_Y" "$*" "$C_N" >&2; fi
    log_file "WARN $*"
}
# a heading; in the installer it is also the line next to the progress bar
step() {
    (( KF_PROTOCOL )) && printf '@@detail %s\n' "$*"
    printf '\n%s==> %s%s\n' "$C_B" "$*" "$C_N"
    log_file "==> $*"
}
note() { if (( KF_PROTOCOL )); then printf '@@note %s\n' "$*"; else printf '  %s\n' "$*"; fi; log_file "NOTE $*"; }
progress() { (( KF_PROTOCOL )) && printf '@@progress %d %d\n' "$1" "$2"; return 0; }
detail()   { (( KF_PROTOCOL )) && printf '@@detail %s\n' "$*"; return 0; }

die() {
    printf '%skernelforge: %s%s\n' "$C_R" "$*" "$C_N" >&2
    log_file "FATAL $*"
    exit 1
}

# Runs a command as root. As root already: directly. Otherwise sudo; the installer has asked
# for the password before (KF_NONINTERACTIVE=1: never prompt, its steps have no terminal).
priv() {
    if (( EUID == 0 )); then "$@"
    elif (( KF_NONINTERACTIVE )); then sudo -n -- "$@"
    else sudo -- "$@"; fi
}

# Runs a command with its output in the log only; on failure the end of it is shown
run_logged() {
    local rc=0
    log_file "RUN $*"
    "$@" >> "${LOGFILE:-/dev/null}" 2>&1 </dev/null || rc=$?
    if (( rc )); then
        warn "failed ($rc): ${*:1:4}"
        [[ -n $LOGFILE ]] && tail -n 15 "$LOGFILE" | while IFS= read -r l; do printf '    %s\n' "$(clean "$l")" >&2; done
    fi
    return "$rc"
}

init_logging() {
    local dir=${XDG_STATE_HOME:-$HOME/.local/state}/kernelforge stamp
    (umask 077; mkdir -p "$dir") || die "cannot create $dir"
    printf -v stamp '%(%Y%m%d-%H%M%S)T' -1
    LOGFILE=$dir/kernelforge-$stamp.log
    (umask 077; : > "$LOGFILE") || die "cannot write $LOGFILE"
}

mktmp() {
    local d
    d=$(mktemp -d "${1:-${TMPDIR:-/tmp}}/kernelforge.XXXXXX") || die "mktemp failed"
    TMP_DIRS+=("$d")
    MKTMP=$d
}

rollback() {
    local p i
    for (( i = ${#ROLLBACK[@]} - 1; i >= 0; i-- )); do
        p=${ROLLBACK[i]}
        # only what this run created below /boot, /lib/modules and the ESP
        case $p in
            "$KF_SYSROOT"/boot/*|"$KF_SYSROOT"/lib/modules/?*|"$KF_SYSROOT"/efi/*|"$KF_SYSROOT"/boot/efi/*) ;;
            *) [[ -n ${ESP-} && $p == "$ESP"/?* ]] || continue ;;
        esac
        [[ $p == *..* ]] && continue
        priv rm -rf -- "$p" 2>/dev/null
    done
    ROLLBACK=()
}

on_exit() {
    local rc=$?
    if (( ${#ROLLBACK[@]} )); then
        printf '%skernelforge: failed, removing what was installed so far%s\n' "$C_Y" "$C_N" >&2
        rollback
    fi
    local d
    for d in "${TMP_DIRS[@]}"; do
        [[ -d $d/private-keys-v1.d ]] && GNUPGHOME=$d gpgconf --kill all 2>/dev/null
        rm -rf -- "$d"
    done
    [[ -n $LOGFILE && $rc -ne 0 ]] && printf 'kernelforge: log: %s\n' "$LOGFILE" >&2
    exit "$rc"
}

# https only, TLS 1.2+, with retries
curl_get() { curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 20 "$@"; }

# free bytes at a path (the nearest existing parent)
free_bytes() {
    local p=$1 kb
    while [[ ! -e $p && $p != / ]]; do p=${p%/*}; [[ -n $p ]] || p=/; done
    kb=$(df -Pk -- "$p" 2>/dev/null | awk 'NR==2 {print $4}')
    [[ $kb =~ ^[0-9]+$ ]] || kb=0
    echo $(( kb * 1024 ))
}
