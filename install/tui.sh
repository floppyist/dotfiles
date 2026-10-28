# shellcheck shell=bash
# install/tui.sh  ·  the full-screen installer. Plain bash and escape sequences: it runs on a
# system where nothing of this desktop is installed yet (no python, no dialog, maybe no Nerd
# Font), in any terminal and on the Linux console (16 colors and ASCII there).
#
#   ┌──────────────────────────────────────────────────────────────────────────┐
#   │ [dotfiles] [Void x86_64] [AMD Renoir (amdgpu)] [user@host]   mode › plan │  header
#   │  Modules                       │ Graphics drivers                        │
#   │ ▌● Desktop              12 new │ Mesa for the GPUs of this machine: …    │  list │ details
#   │  ● System update           set │                                         │
#   │ [space] toggle  [enter] continue                                         │  key hints
#   └──────────────────────────────────────────────────────────────────────────┘

TUI_ON=0 TUI_RESIZE=0 TUI_INT=0 SPIN=0 KEYBUF=""

# ── Terminal ──────────────────────────────────────────────────────────────────────

tui_start() {
    [[ -t 0 && -t 1 ]] || return 1
    TUI_STTY=$(stty -g 2>/dev/null) || return 1
    tui_raw
    printf '\e[?1049h\e[?25l\e[?7l\e[H\e[2J'
    TUI_ON=1
    trap 'TUI_RESIZE=1' WINCH
    trap 'TUI_INT=1' INT
    trap '' QUIT TSTP      # Ctrl+\ and Ctrl+Z: the terminal would stay in the installer's mode
    tui_size
    tui_theme
}

# Keys arrive one by one, without echo. Ctrl+C is a key: bash's read switches ISIG back on while
# it waits, so the SIGINT becomes the key ctrl-c (read_key). The steps run in the background and
# ignore SIGINT (bash does that for asynchronous commands): a running xbps is never interrupted.
tui_raw() { stty -echo -icanon -isig min 1 time 0 2>/dev/null; }

tui_stop() {
    (( TUI_ON )) || return 0
    TUI_ON=0
    printf '\e[0m\e[?7h\e[?25h\e[?1049l'
    stty "$TUI_STTY" 2>/dev/null
}

tui_size() {
    local s
    s=$(stty size 2>/dev/null)
    H=${s%% *} W=${s##* }
    [[ $H =~ ^[0-9]+$ && $W =~ ^[0-9]+$ ]] || { H=24; W=80; }
}

tui_small() { (( W < 64 || H < 20 )); }

# ── Colors and glyphs ─────────────────────────────────────────────────────────────

# 38|48 #rrggbb -> _SGR (truecolor, or the nearest of the 256 colors)
sgr() {
    local r=$(( 16#${2:1:2} )) g=$(( 16#${2:3:2} )) b=$(( 16#${2:5:2} ))
    if (( CM == 24 )); then _SGR=$'\e['"$1;2;$r;$g;${b}m"; return; fi
    local lv=(0 95 135 175 215 255) qr qg qb dc dg avg gi gv
    qr=$(( r < 48 ? 0 : r < 115 ? 1 : (r - 35) / 40 ))
    qg=$(( g < 48 ? 0 : g < 115 ? 1 : (g - 35) / 40 ))
    qb=$(( b < 48 ? 0 : b < 115 ? 1 : (b - 35) / 40 ))
    dc=$(( (r - lv[qr]) ** 2 + (g - lv[qg]) ** 2 + (b - lv[qb]) ** 2 ))
    avg=$(( (r + g + b) / 3 ))
    gi=$(( avg > 238 ? 23 : avg < 3 ? 0 : (avg - 3) / 10 ))
    gv=$(( 8 + 10 * gi ))
    dg=$(( (r - gv) ** 2 + (g - gv) ** 2 + (b - gv) ** 2 ))
    if (( dg < dc )); then _SGR=$'\e['"$1;5;$(( 232 + gi ))m"
    else _SGR=$'\e['"$1;5;$(( 16 + 36 * qr + 6 * qg + qb ))m"; fi
}

tui_theme() {
    # The palette of dotfiles.conf once `dotfiles apply` ran, these defaults before
    local DF_BG='#191c1c' DF_SURFACE='#252a2a' DF_OVERLAY='#313838' DF_FG='#ebdbb2' DF_SUBTLE='#a89984'
    local DF_MUTED='#7c6f64' DF_ACCENT='#cc241d' DF_ACCENT_TEXT='#fb4934' DF_ON_ACCENT='#191c1c'
    local DF_GREEN_HI='#b8bb26' DF_YELLOW_HI='#fabd2f' DF_RED_HI='#fb4934' DF_BLUE_HI='#83a598'
    # shellcheck source=/dev/null
    . "$CONFIG/dotfiles/theme.sh" 2>/dev/null
    case ${TERM-} in
        linux|vt*|cons*|dumb) CM=16 ;;
        *) if [[ ${COLORTERM-} == @(truecolor|24bit) || ${TERM-} == @(alacritty*|*kitty*|foot*|wezterm*|*-direct) ]]
           then CM=24; else CM=256; fi ;;
    esac
    declare -gA F=() B=()
    if (( CM == 16 )); then
        F=([bg]=$'\e[30m' [surface]=$'\e[90m' [overlay]=$'\e[90m' [fg]=$'\e[39m' [subtle]=$'\e[37m'
           [muted]=$'\e[90m' [accent]=$'\e[31m' [accent_text]=$'\e[91m' [on_accent]=$'\e[97m'
           [ok]=$'\e[32m' [warn]=$'\e[33m' [err]=$'\e[91m' [info]=$'\e[36m')
        B=([bg]=$'\e[49m' [surface]=$'\e[49m' [accent]=$'\e[41m')
    else
        local t hex
        local -A hexes=([bg]=$DF_BG [surface]=$DF_SURFACE [overlay]=$DF_OVERLAY [fg]=$DF_FG
            [subtle]=$DF_SUBTLE [muted]=$DF_MUTED [accent]=$DF_ACCENT [accent_text]=$DF_ACCENT_TEXT
            [on_accent]=$DF_ON_ACCENT [ok]=$DF_GREEN_HI [warn]=$DF_YELLOW_HI [err]=$DF_RED_HI
            [info]=$DF_BLUE_HI)
        for t in "${!hexes[@]}"; do
            hex=${hexes[$t]}
            [[ $hex =~ ^#[0-9a-fA-F]{6}$ ]] || hex='#808080'
            sgr 38 "$hex"; F[$t]=$_SGR
            sgr 48 "$hex"; B[$t]=$_SGR
        done
    fi
    BOLD=$'\e[1m' NOBOLD=$'\e[22m'
    N=$'\e[0m'${B[bg]}${F[fg]}      # base style: text on the background
    tui_glyphs
}

tui_glyphs() {
    local lc=${LC_ALL:-${LC_CTYPE:-${LANG-}}}
    if [[ ${TERM-} != @(linux|vt*|cons*|dumb) && $lc == *[Uu][Tt][Ff]?(-)8* ]]; then
        G_BAR='▌' G_ON='●' G_OFF='○' G_OK='✓' G_FAIL='✗' G_PEND='·' G_SKIP='–' G_DOT='·'
        G_HL='─' G_VL='│' G_TL='┌' G_TR='┐' G_BL='└' G_BR='┘' G_FILL='█' G_TRACK='█'
        G_ELL='…' G_SEP='›' G_UPDN='↑↓' G_LR='←→' G_SPIN=(▘ ▝ ▗ ▖)
    else
        G_BAR='>' G_ON='*' G_OFF='-' G_OK='+' G_FAIL='x' G_PEND='.' G_SKIP='-' G_DOT='-'
        G_HL='-' G_VL='|' G_TL='+' G_TR='+' G_BL='+' G_BR='+' G_FILL='#' G_TRACK='-'
        G_ELL='~' G_SEP='>' G_UPDN='up/down' G_LR='left/right' G_SPIN=('|' '/' '-' '\')
    fi
}

# ── Text helpers (results in globals: no subshells while drawing) ─────────────────

# TEXT WIDTH -> _F: exactly WIDTH characters, cut with an ellipsis or padded
# (control characters are dropped: no text reaches the terminal as escape sequences)
fit() {
    local t=${1//[[:cntrl:]]/} w=$2
    (( w > 0 )) || { _F=""; return; }
    (( ${#t} > w )) && t=${t:0:w-1}$G_ELL
    printf -v _F '%s%*s' "$t" $(( w - ${#t} )) ''
}

# the same, right aligned
rfit() {
    local t=${1//[[:cntrl:]]/} w=$2
    (( w > 0 )) || { _F=""; return; }
    (( ${#t} > w )) && t=${t:0:w-1}$G_ELL
    printf -v _F '%*s%s' $(( w - ${#t} )) '' "$t"
}

# CHAR COUNT -> _R
rep() {
    (( $2 > 0 )) || { _R=""; return; }
    printf -v _R '%*s' "$2" ''
    _R=${_R// /$1}
}

# TEXT WIDTH -> WRAP (lines)
wrap() {
    local -; set -f
    local IFS=$' \t\n' w=$2 line="" word
    WRAP=()
    (( w < 4 )) && w=4
    for word in ${1//[[:cntrl:]]/ }; do
        while (( ${#word} > w )); do
            [[ -n $line ]] && { WRAP+=("$line"); line=""; }
            WRAP+=("${word:0:w}")
            word=${word:w}
        done
        if [[ -z $line ]]; then line=$word
        elif (( ${#line} + 1 + ${#word} <= w )); then line+=" $word"
        else WRAP+=("$line"); line=$word
        fi
    done
    [[ -n $line ]] && WRAP+=("$line")
}

# ── Detail lines (DL, at most DW characters wide) ─────────────────────────────────

d_reset() { DL=(); }
d_blank() { DL+=(""); }

# COLOR TEXT [INDENT]: wrapped text
d_text() {
    local l pad=""
    printf -v pad '%*s' "${3:-0}" ''
    wrap "$2" $(( DW - ${3:-0} ))
    for l in "${WRAP[@]}"; do DL+=("$pad$1$l$N"); done
}

# TEXT [TAG]: a heading, the tag muted after it
d_head() {
    local t=$1 tag=${2-}
    (( ${#t} + 2 + ${#tag} > DW )) && tag=""
    (( ${#t} > DW )) && { fit "$t" "$DW"; t=$_F; }
    DL+=("$BOLD${F[fg]}$t$NOBOLD${tag:+  ${F[muted]}$tag}$N")
}

# KEY VALUE [COLOR] [KEYWIDTH]: the value wraps under itself
d_kv() {
    local kw=${4:-11} c=${3:-${F[fg]}} l k first=1
    wrap "$2" $(( DW - kw ))
    (( ${#WRAP[@]} )) || WRAP=("")
    for l in "${WRAP[@]}"; do
        if (( first )); then fit "$1" "$kw"; k=$_F; first=0; else printf -v k '%*s' "$kw" ''; fi
        DL+=("${F[subtle]}$k$c$l$N")
    done
}

# KEY [KEYWIDTH]: the PLAN lines as a list ("!" in front: a warning, "%": muted), the key in
# front of the first one
d_plan() {
    local kw=${2:-0} l c g k first=1 w
    for l in "${PLAN[@]}"; do
        case $l in
            '!'*) l=${l#!}; c=${F[warn]}; g='!' ;;
            '%'*) l=${l#%}; c=${F[muted]}; g=$G_DOT ;;
            *)    c=${F[fg]}; g=$G_DOT ;;
        esac
        wrap "$l" $(( DW - kw - 2 ))
        w=1
        for l in "${WRAP[@]}"; do
            if (( first )); then fit "$1" "$kw"; k=$_F; first=0; else printf -v k '%*s' "$kw" ''; fi
            if (( w )); then DL+=("${F[subtle]}$k${F[muted]}$g $c$l$N"); w=0
            else DL+=("${F[subtle]}$k  $c$l$N"); fi
        done
    done
}

# ── Frame ─────────────────────────────────────────────────────────────────────────
# FR holds the rows of the screen. A row never reaches the last column: some terminals would
# wrap, and \e[K there would erase the last character.

tui_clear() { FR=(); }

tui_flush() {
    local out="" i
    for (( i = 0; i < H; i++ )); do
        out+=$'\e['"$(( i + 1 ));1H$N${FR[i]-}$N"$'\e[K'
    done
    printf '%s' "$out"
}

# The top row: an accent block, the machine in capsules, the steps of the installer.
# $1: current step (1 mode, 2 modules, 3 plan, 4 install; 0 none)
tui_header() {
    local s=" ${B[accent]}${F[on_accent]}$BOLD dotfiles $N" used=11 c cr="" crl=0 i nm col
    local names=(mode modules plan install)
    if (( ${1:-0} && W >= 100 )); then
        for i in 1 2 3 4; do
            nm=${names[i - 1]}
            if (( i < $1 )); then col=${F[subtle]}
            elif (( i == $1 )); then col=$BOLD${F[accent_text]}
            else col=${F[muted]}; fi
            (( i > 1 )) && { cr+="${F[muted]} $G_SEP "; (( crl += 3 )); }
            cr+="$col$nm$N"
            (( crl += ${#nm} ))
        done
    fi
    for c in "$HDR_SYS" "$HDR_GPU" "$HDR_USER"; do
        c=${c//[[:cntrl:]]/}
        [[ -n $c ]] || continue
        (( used + ${#c} + 3 + crl + 2 > W - 1 )) && break
        s+=" ${B[surface]}${F[fg]} $c $N"
        (( used += ${#c} + 3 ))
    done
    if (( crl )); then
        printf -v c '%*s' $(( W - 2 - used - crl )) ''
        s+="$c$cr"
    fi
    FR[0]=$s
}

# The bottom row: KEY LABEL pairs, the keys in capsules
tui_footer() {
    local s=" " used=1 k l
    while (( $# > 1 )); do
        k=$1 l=$2
        shift 2
        (( used + ${#k} + ${#l} + 5 > W - 1 )) && break
        if (( CM == 16 )); then s+="${F[fg]}[$k]$N ${F[muted]}$l$N  "
        else s+="${B[surface]}${F[fg]} $k $N ${F[muted]}$l$N  "; fi
        (( used += ${#k} + ${#l} + 5 ))
    done
    FR[H - 1]=$s
}

# Two columns: LR (exactly LW wide) | RR, titles $1 and $2
tui_layout() {
    LW=$(( W * 2 / 5 ))
    (( LW < 32 )) && LW=32
    (( LW > 46 )) && LW=46
    RW=$(( W - LW - 6 ))
    if (( RW < 26 )); then LW=$(( W - 3 )); RW=0; fi
    BH=$(( H - 5 ))
}

tui_columns() {
    local i sep=${F[overlay]}$G_VL$N
    fit "$1" "$LW"
    FR[2]=" ${F[subtle]}$BOLD$_F$N"
    (( RW )) && { fit "$2" "$RW"; FR[2]+=" $sep ${F[subtle]}$BOLD$_F$N"; }
    for (( i = 0; i < BH; i++ )); do
        if [[ -n ${LR[i]-} ]]; then FR[3 + i]=" ${LR[i]}"; else printf -v "FR[$(( 3 + i ))]" ' %*s' "$LW" ''; fi
        (( RW )) && FR[3 + i]+=" $sep ${RR[i]-}"
    done
}

tui_too_small() {
    local m="Please make the terminal larger: 64 x 20 (now $W x $H)"
    tui_clear
    FR[H / 2]="  ${F[warn]}$m$N"
    tui_footer q quit
    tui_flush
}

# A message while something takes a moment
tui_splash() {
    tui_clear
    tui_header "${2:-0}"
    FR[H / 2]="   ${F[accent_text]}${G_SPIN[0]}$N ${F[subtle]}$1$G_ELL$N"
    tui_flush
}

# ── Keys ──────────────────────────────────────────────────────────────────────────

# [TIMEOUT] -> KEY: up down left right pgup pgdn home end enter space tab backtab esc
# backspace ctrl-c, or the character. Returns 1 on timeout (or a signal like SIGWINCH).
read_key() {
    local k c seq="" rc=0
    KEY=""
    if [[ -n $KEYBUF ]]; then k=$KEYBUF KEYBUF=""
    elif [[ -n ${1-} ]]; then IFS= read -rsn1 -t "$1" k || rc=$?
    else IFS= read -rsn1 k || rc=$?; fi
    if (( TUI_INT )); then TUI_INT=0; KEY=ctrl-c; return 0; fi
    (( rc == 0 )) || return 1
    case $k in
        $'\e')
            if IFS= read -rsn1 -t 0.03 c && [[ $c == $'\e' ]]; then
                KEY=esc KEYBUF=$c        # Esc, then the next key (e.g. an arrow) right after it
            elif [[ ${c-} == @('['|O) ]]; then
                while IFS= read -rsn1 -t 0.03 c; do
                    seq+=$c
                    [[ $c == [A-Za-z~] ]] && break
                done
                case $seq in
                    A) KEY=up ;; B) KEY=down ;; C) KEY=right ;; D) KEY=left ;;
                    5~) KEY=pgup ;; 6~) KEY=pgdn ;; H|1~|7~) KEY=home ;; F|4~|8~) KEY=end ;;
                    Z) KEY=backtab ;; *) KEY=unknown ;;
                esac
            elif [[ -n ${c-} ]]; then KEY=unknown      # Alt+key
            else KEY=esc; fi ;;
        "")              KEY=enter ;;
        " ")             KEY=space ;;
        $'\t')           KEY=tab ;;
        $'\x03')         KEY=ctrl-c ;;
        $'\x7f'|$'\b')   KEY=backspace ;;
        *)               KEY=$k ;;
    esac
    return 0
}

# ── Screens: a list with details ──────────────────────────────────────────────────
# Set before list_screen:
#   LS_N LS_SEL          items, the selected one (it stays in LS_SEL)
#   LS_ROWFN f           f INDEX SELECTED WIDTH -> _ROW (exactly WIDTH characters)
#   LS_DETFN f           f INDEX -> DL (details, DW wide)
#   LS_EXTRAFN f         optional: f -> XL, rows under the list (LW wide)
#   LS_KEYFN f           f KEY: 0 redraw, 1 not used, 2 leave (LS_OUT says why)
#   LS_TL LS_TR LS_CRUMB LS_HINTS

list_screen() {
    local off=0 dirty=1 i rc
    while :; do
        if (( TUI_RESIZE )); then TUI_RESIZE=0; tui_size; dirty=1; fi
        if (( dirty )); then
            dirty=0
            if tui_small; then tui_too_small; else
                tui_clear
                tui_header "$LS_CRUMB"
                tui_layout
                (( LS_SEL < off )) && off=$LS_SEL
                (( LS_SEL >= off + BH )) && off=$(( LS_SEL - BH + 1 ))
                LR=()
                for (( i = off; i < LS_N && i - off < BH; i++ )); do
                    "$LS_ROWFN" "$i" $(( i == LS_SEL )) "$LW"
                    LR+=("$_ROW")
                done
                if [[ -n ${LS_EXTRAFN-} ]]; then
                    XL=()
                    "$LS_EXTRAFN"
                    (( ${#LR[@]} + 2 + ${#XL[@]} <= BH )) && LR+=("" "" "${XL[@]}")
                fi
                RR=()
                if (( RW )); then DW=$RW; "$LS_DETFN" "$LS_SEL"; RR=("${DL[@]:0:BH}"); fi
                tui_columns "$LS_TL" "$LS_TR"
                tui_footer "${LS_HINTS[@]}"
                tui_flush
            fi
        fi
        read_key 0.3 || continue
        dirty=1
        if tui_small; then [[ $KEY == @(q|ctrl-c) ]] && { LS_OUT=quit; return 0; }; continue; fi
        case $KEY in
            up|k)   (( LS_SEL > 0 )) && (( LS_SEL-- )) ;;
            down|j) (( LS_SEL < LS_N - 1 )) && (( LS_SEL++ )) ;;
            home|g) LS_SEL=0 ;;
            end|G)  LS_SEL=$(( LS_N - 1 )) ;;
            *)      "$LS_KEYFN" "$KEY"; rc=$?
                    (( rc == 2 )) && return 0 ;;
        esac
    done
}

# ── Screens: a page of text with buttons ──────────────────────────────────────────
# DOC_FN builds DL for the width DW. doc_screen CRUMB TITLE BUTTON...
# -> DOC_BTN: the button, -1 Esc, -2 Ctrl+C. DOC_SEL: preselected button.

doc_screen() {
    local crumb=$1 title=$2
    shift 2
    local btns=("$@") sel=${DOC_SEL:-0} off=0 dirty=1 lastw=0 dh i s
    while :; do
        if (( TUI_RESIZE )); then TUI_RESIZE=0; tui_size; dirty=1; fi
        if (( dirty )); then
            dirty=0
            if tui_small; then tui_too_small; else
                tui_clear
                tui_header "$crumb"
                DW=$(( W - 7 ))
                (( W != lastw )) && { "$DOC_FN"; lastw=$W; }
                dh=$(( H - 7 ))
                (( off > ${#DL[@]} - dh )) && off=$(( ${#DL[@]} - dh ))
                (( off < 0 )) && off=0
                FR[2]="  ${DOC_TITLE_C:-${F[fg]}}$BOLD$title$N"
                for (( i = 0; i < dh; i++ )); do FR[3 + i]="   ${DL[off + i]-}"; done
                s="   "
                for i in "${!btns[@]}"; do
                    if (( CM == 16 )); then
                        if (( i == sel )); then s+=$'\e[7m'"  ${btns[i]}  "$'\e[27m'"  "
                        else s+="[ ${btns[i]} ]  "; fi
                    elif (( i == sel )); then s+="${B[accent]}${F[on_accent]}$BOLD  ${btns[i]}  $N  "
                    else s+="${B[surface]}${F[fg]}  ${btns[i]}  $N  "; fi
                done
                (( ${#DL[@]} > dh )) &&
                    s+="${F[muted]}  lines $(( off + 1 ))-$(( off + dh > ${#DL[@]} ? ${#DL[@]} : off + dh )) of ${#DL[@]}$N"
                FR[H - 3]=$s
                tui_footer "${DOC_HINTS[@]}"
                tui_flush
            fi
        fi
        read_key 0.3 || continue
        dirty=1
        if tui_small; then [[ $KEY == @(q|ctrl-c) ]] && { DOC_BTN=-2; return 0; }; continue; fi
        case $KEY in
            left|h|backtab) (( sel > 0 )) && (( sel-- )) ;;
            right|l)        (( sel < ${#btns[@]} - 1 )) && (( sel++ )) ;;
            tab)            sel=$(( (sel + 1) % ${#btns[@]} )) ;;
            up|k)           (( off-- )) ;;
            down|j)         (( off++ )) ;;
            pgup|b)         (( off -= dh )) ;;
            pgdn|space)     (( off += dh )) ;;
            home|g)         off=0 ;;
            end|G)          off=${#DL[@]} ;;
            enter)          DOC_BTN=$sel; return 0 ;;
            esc|q)          DOC_BTN=-1; return 0 ;;
            ctrl-c)         DOC_BTN=-2; return 0 ;;
        esac
    done
}

# ── Main menu ─────────────────────────────────────────────────────────────────────

MENU_IDS=(complete modules links quit)
MENU_ITEMS=("Complete installation" "Choose modules" "Update links" "Quit")

row_menu() {
    fit "${MENU_ITEMS[$1]}" $(( $3 - 2 ))
    if (( $2 )); then _ROW="${B[surface]}${F[accent]}$G_BAR ${F[fg]}$BOLD$_F$N"
    else _ROW="  ${F[fg]}$_F$N"; fi
}

det_main() {
    local m
    d_reset
    case ${MENU_IDS[$1]} in
        complete)
            d_text "${F[fg]}" "Everything this desktop needs, in one go: packages and drivers for this machine, \
services, the font, links and theme, Firefox, the Neovim plugins, the start of X and NetworkManager. \
sudo asks for your password once."
            d_blank
            # what the complete installation takes: the defaults (mods_default)
            for m in "${MODULES[@]}"; do
                fit "${M_TITLE[$m]}" 20
                if [[ -z ${M_OFF[$m]} ]]; then
                    mod_status_default "$m"
                    DL+=("${F[accent_text]}$G_ON ${F[fg]}$_F$_STC$_ST$N")
                else
                    DL+=("${F[muted]}$G_OFF $_F${M_OFF[$m]}$N")
                fi
            done
            d_blank
            if (( ! HAVE_XBPS )); then
                d_text "${F[warn]}" "No xbps: this is not Void Linux. Packages and services are left out, \
only the steps in your home directory run."
            elif (( TOTAL_DL )); then
                human_size "$TOTAL_DL"
                d_kv "Download" "about $_HS (all modules)" "${F[fg]}"
            fi ;;
        modules)
            d_text "${F[fg]}" "Pick the parts yourself: audio, network, Bluetooth, Neovim, Firefox, mail, \
music and more. The desktop itself is always part of it."
            d_blank
            d_text "${F[subtle]}" "Every module shows what it installs and changes before anything happens." ;;
        links)
            d_text "${F[fg]}" "Link new and moved files of this repository and generate the theme again, \
for example after git pull. No packages, no root."
            d_blank
            links_plan
            d_kv "Links" "$LINKS_PLAN_TODO to create or fix"
            (( ${#LINKS_PLAN_BACKUPS[@]} )) && d_kv "Backups" "${#LINKS_PLAN_BACKUPS[@]} files in the way (kept as *.bak)" ;;
        quit)
            d_text "${F[fg]}" "Leave without changing anything." ;;
    esac
}

# "This machine" under the menu
extra_machine() {
    local kw=11 vw=$(( LW - 12 )) gpu net
    XL=()
    fit "This machine" "$LW"; XL+=("${F[subtle]}$BOLD$_F$N")
    ex_row() { fit "$1" "$kw"; local k=$_F; fit "$2" "$vw"; XL+=("${F[muted]}$k ${F[fg]}$_F$N"); }
    gpu=${GPU_LIST:-none found}
    if (( NM_ON )); then net=NetworkManager
    elif (( ${#NET_OLD[@]} )); then net=${NET_OLD[*]}
    else net="no service"; fi
    ex_row System "$OS_NAME $ARCH"
    ex_row Graphics "$gpu"
    ex_row Backlight "${BACKLIGHT:-none}"
    ex_row Battery "${BATTERY:-none}"
    ex_row Bluetooth "${BT_ADAPTER:-none}"
    ex_row WiFi "${WIFI_IFS[*]:-none}"
    ex_row Network "$net"
    ex_row Session "${DM:-startx}"
    ex_row Packages "${#PKG_HAVE[@]} installed, ${UPDATES:-0} updates"
}

key_main() {
    case $1 in
        enter|right|l) LS_OUT=${MENU_IDS[LS_SEL]}; return 2 ;;
        q|esc|ctrl-c)  LS_OUT=quit; return 2 ;;
    esac
    return 1
}

screen_main() {
    LS_N=${#MENU_ITEMS[@]} LS_SEL=${MAIN_SEL:-0} LS_ROWFN=row_menu LS_DETFN=det_main
    LS_EXTRAFN=extra_machine LS_KEYFN=key_main LS_TL="Install" LS_TR="" LS_CRUMB=1
    LS_HINTS=("$G_UPDN" move enter select q quit)
    list_screen
    MAIN_SEL=$LS_SEL
}

# ── Modules ───────────────────────────────────────────────────────────────────────

# status of module $1 for the list -> _ST _STC
mod_status() {
    local m=$1
    _STC=${F[subtle]}
    if [[ -n ${M_OFF[$m]} ]] && ! (( SEL[$m] )); then _ST=${M_OFF[$m]}; _STC=${F[muted]}
    else mod_status_default "$m"; fi
}

# the same, regardless of the selection
mod_status_default() {
    local m=$1
    _STC=${F[subtle]}
    if (( M_MISSING[$m] )); then _ST="${M_MISSING[$m]} new"
    elif (( M_WORK[$m] )); then _ST="to set up"
    else _ST="done"; _STC=${F[ok]}; fi
}

row_module() {
    local m=${MODULES[$1]} w=$3 chk chkc bg tw
    if (( ${M_REQ[$m]:-0} )); then chk=$G_ON chkc=${F[muted]}
    elif (( SEL[$m] )); then chk=$G_ON chkc=${F[accent_text]}
    else chk=$G_OFF chkc=${F[muted]}; fi
    mod_status "$m"
    tw=$(( w - 6 - ${#_ST} ))
    fit "${M_TITLE[$m]}" "$tw"
    if (( $2 )); then
        bg=${B[surface]}
        _ROW="$bg${F[accent]}$G_BAR $chkc$chk $BOLD${F[fg]}$_F$NOBOLD $_STC$_ST $N"
    else
        _ROW="  $chkc$chk ${F[fg]}$_F $_STC$_ST $N"
    fi
}

det_module() {
    local m=${MODULES[$1]} p have=() new=() st l
    d_reset
    if (( ${M_REQ[$m]:-0} )); then d_head "${M_TITLE[$m]}" "always part of it"
    elif (( SEL[$m] )); then d_head "${M_TITLE[$m]}" "selected"
    else d_head "${M_TITLE[$m]}" "${M_OFF[$m]:-not selected}"; fi
    d_text "${F[subtle]}" "${M_DESC[$m]}"
    case $m in
        graphics)
            d_blank
            d_kv Found "${GPU_LIST:-no GPU found}"
            if (( GPU_NVIDIA )); then
                nvidia_label "$NVIDIA_DRIVER"
                d_kv Driver "$_NL" "${F[fg]}"
                (( ${#NVIDIA_DRIVERS[@]} > 1 )) && d_kv "" "d: another driver" "${F[muted]}"
            fi ;;
        laptop)    d_blank; d_kv Found "${BACKLIGHT:-no backlight}${BATTERY:+, $BATTERY}" ;;
        bluetooth) d_blank; d_kv Found "${BT_ADAPTER:-no adapter}" ;;
        network)
            d_blank
            if (( NM_ON )); then l=NetworkManager; elif (( ${#NET_OLD[@]} )); then l=${NET_OLD[*]}; else l=none; fi
            d_kv Now "$l"
            d_kv WiFi "${WIFI_IFS[*]:-no WiFi}" ;;
        autostart) d_blank; d_kv Now "${DM:+display manager }${DM:-startx by hand}" ;;
    esac
    mod_pkgs "$m"
    if (( ${#MP[@]} )); then
        for p in "${MP[@]}"; do if pkg_have "$p"; then have+=("$p"); else new+=("$p"); fi; done
        d_blank
        (( ${#new[@]} )) && d_kv New "${new[*]}" "${F[fg]}"
        (( ${#have[@]} )) && d_kv Installed "${have[*]}" "${F[muted]}"
    fi
    [[ -n ${M_STEPS[$m]-} ]] && d_blank
    for st in ${M_STEPS[$m]-}; do
        plan_step "$st" "$m" || (( ${#PLAN[@]} )) || PLAN=("%nothing to do")
        # the step in a column when there is room, else as a heading
        if (( DW >= 56 )); then
            d_plan "${STEP_TITLE[$st]}" 18
        else
            DL+=("${F[subtle]}${STEP_TITLE[$st]}$N")
            d_plan
        fi
    done
}

key_modules() {
    local m=${MODULES[LS_SEL]} x on=1 i
    case $1 in
        space|x)
            (( ${M_REQ[$m]:-0} )) || SEL[$m]=$(( 1 - SEL[$m] ))
            return 0 ;;
        a)  # all optional modules on, or off if they are all on already
            for x in "${MODULES[@]}"; do (( ${M_REQ[$x]:-0} || SEL[$x] )) || on=0; done
            for x in "${MODULES[@]}"; do (( ${M_REQ[$x]:-0} )) || SEL[$x]=$(( 1 - on )); done
            return 0 ;;
        d)  if [[ $m == graphics ]] && (( GPU_NVIDIA && ${#NVIDIA_DRIVERS[@]} > 1 )); then
                for i in "${!NVIDIA_DRIVERS[@]}"; do [[ ${NVIDIA_DRIVERS[i]} == "$NVIDIA_DRIVER" ]] && break; done
                NVIDIA_DRIVER=${NVIDIA_DRIVERS[(i + 1) % ${#NVIDIA_DRIVERS[@]}]}
                mods_scan
            fi
            return 0 ;;
        enter|right|l) LS_OUT=next; return 2 ;;
        esc|left|h|q)  LS_OUT=back; return 2 ;;
        ctrl-c)        LS_OUT=quit; return 2 ;;
    esac
    return 1
}

screen_modules() {
    LS_N=${#MODULES[@]} LS_SEL=${MOD_SEL:-0} LS_ROWFN=row_module LS_DETFN=det_module LS_EXTRAFN=""
    LS_KEYFN=key_modules LS_TL="Modules" LS_TR="Details" LS_CRUMB=2
    LS_HINTS=("$G_UPDN" move space toggle a all enter continue esc back)
    (( GPU_NVIDIA )) && LS_HINTS+=(d "NVIDIA driver")
    list_screen
    MOD_SEL=$LS_SEL
}

# NVIDIA: which driver (complete installation)
row_nvidia() {
    nvidia_label "${NVIDIA_DRIVERS[$1]}"
    fit "$_NL" $(( $3 - 2 ))
    if (( $2 )); then _ROW="${B[surface]}${F[accent]}$G_BAR ${F[fg]}$BOLD$_F$N"
    else _ROW="  ${F[fg]}$_F$N"; fi
}

det_nvidia() {
    d_reset
    case ${NVIDIA_DRIVERS[$1]} in
        nouveau)   d_text "${F[fg]}" "The open source driver in Mesa: works with every GeForce and needs nothing \
else, but is slower, and the newest cards may not have power management yet." ;;
        nvidia)    d_text "${F[fg]}" "The proprietary driver for Turing and newer (GTX 16xx, RTX 20xx and later). \
Adds the nonfree repository and builds its kernel module with DKMS (linux-headers)." ;;
        nvidia580) d_text "${F[fg]}" "The last proprietary driver for Maxwell, Pascal and Volta (GTX 750 to \
GTX 1080, Titan V). Nonfree repository, DKMS." ;;
        nvidia470) d_text "${F[fg]}" "The legacy proprietary driver for Kepler (GTX 600 and 700). Nonfree \
repository, DKMS." ;;
    esac
    d_blank
    d_kv Found "$GPU_LIST"
}

key_nvidia() {
    case $1 in
        enter|right|l) NVIDIA_DRIVER=${NVIDIA_DRIVERS[LS_SEL]}; LS_OUT=next; return 2 ;;
        esc|left|h|q)  LS_OUT=back; return 2 ;;
        ctrl-c)        LS_OUT=quit; return 2 ;;
    esac
    return 1
}

screen_nvidia() {
    local i
    LS_N=${#NVIDIA_DRIVERS[@]} LS_SEL=0 LS_ROWFN=row_nvidia LS_DETFN=det_nvidia LS_EXTRAFN=""
    for i in "${!NVIDIA_DRIVERS[@]}"; do [[ ${NVIDIA_DRIVERS[i]} == "$NVIDIA_DRIVER" ]] && LS_SEL=$i; done
    LS_KEYFN=key_nvidia LS_TL="NVIDIA driver" LS_TR="" LS_CRUMB=2
    LS_HINTS=("$G_UPDN" move enter choose esc back)
    list_screen
    mods_scan
}

# ── Plan ──────────────────────────────────────────────────────────────────────────

plan_compute() {
    sel_pkgs
    sel_steps
    TX_COUNT=0 TX_DL=0 TX_INST=0 TX_UNKNOWN=()
    (( HAVE_XBPS && ${#SM[@]} )) && xbps_dry "${SM[@]}"
}

build_plan() {
    local st m root=0 home=0 off=() kw=20
    d_reset
    d_text "${F[subtle]}" "Nothing has changed yet. This is what happens, in this order:"
    if (( ${#SM[@]} )); then
        d_blank
        d_head "Packages"
        if (( TX_COUNT )); then
            human_size "$TX_DL"; local dl=$_HS
            human_size "$TX_INST"
            d_kv "" "${#SM[@]} new, $TX_COUNT with dependencies, $dl download, $_HS on disk" "${F[fg]}" 2
        else
            d_kv "" "${#SM[@]} new" "${F[fg]}" 2
        fi
        d_text "${F[muted]}" "${SM[*]}" 2
        (( ${#TX_UNKNOWN[@]} )) && d_text "${F[warn]}" "Not in the repository (left out): ${TX_UNKNOWN[*]}" 2
    fi
    for st in "${SS[@]}"; do
        [[ $st == packages ]] && continue
        (( ${STEP_ROOT[$st]:-0} )) && root=1 || home=1
    done
    if (( root )); then
        d_blank
        d_head "System" "as root (sudo)"
        for st in "${SS[@]}"; do
            [[ $st == packages ]] || ! (( ${STEP_ROOT[$st]:-0} )) && continue
            plan_step "$st" || PLAN=("${PLAN[@]}" "%nothing to do")
            d_plan "  ${STEP_TITLE[$st]}" "$kw"
        done
    fi
    if (( home )); then
        d_blank
        d_head "Your home" "as $USER_NAME"
        for st in "${SS[@]}"; do
            (( ${STEP_ROOT[$st]:-0} )) && continue
            plan_step "$st" || PLAN=("${PLAN[@]}" "%nothing to do")
            d_plan "  ${STEP_TITLE[$st]}" "$kw"
        done
    fi
    if [[ ${FLOW-} != links ]]; then
        for m in "${MODULES[@]}"; do
            (( SEL[$m] )) || off+=("${M_TITLE[$m]}${M_OFF[$m]:+ (${M_OFF[$m]})}")
        done
    fi
    if (( ${#off[@]} )); then
        d_blank
        d_head "Not selected"
        printf -v m '%s, ' "${off[@]}"
        d_text "${F[muted]}" "${m%, }" 2
    fi
    if sel_needs_root; then
        d_blank
        d_text "${F[subtle]}" "sudo asks for your password before it starts. Steps that fail can be retried \
or skipped. Log: ${LOG/#$HOME/\~}"
    fi
}

screen_plan() {
    tui_splash "Working out the plan" 3
    plan_compute
    DOC_FN=build_plan DOC_TITLE_C="" DOC_SEL=0
    DOC_HINTS=("$G_LR" choose enter confirm j/k scroll esc back)
    doc_screen 3 "${PLAN_TITLE:-What happens}" "${PLAN_ACTION:-Install}" Back
    case $DOC_BTN in
        0)  return 0 ;;
        -2) return 2 ;;
        *)  return 1 ;;
    esac
}

# ── sudo ──────────────────────────────────────────────────────────────────────────

# Ask for the password once (sudo -v, sudo's own prompt) and keep the permission alive
tui_sudo() {
    local rc y
    if ! command -v sudo >/dev/null; then
        DOC_FN=build_nosudo DOC_TITLE_C=${F[err]} DOC_SEL=0 DOC_HINTS=(enter back)
        doc_screen 4 "sudo is missing" Back
        return 1
    fi
    sudo -n true 2>/dev/null && { sudo_keepalive; return 0; }
    while :; do
        tui_clear
        tui_header 4
        DW=$(( W - 7 ))
        FR[2]="  ${F[fg]}${BOLD}Administrator rights$N"
        d_reset
        d_text "${F[subtle]}" "Packages, services and files in /etc need root. sudo asks for your password \
once and keeps the permission until the installer ends. The installer never sees the password."
        for y in "${!DL[@]}"; do FR[4 + y]="   ${DL[y]}"; done
        y=$(( 4 + ${#DL[@]} + 1 ))
        tui_footer enter confirm ctrl+c back
        tui_flush
        printf '\e[%d;4H\e[?25h' $(( y + 1 ))
        stty "$TUI_STTY" 2>/dev/null
        SUDO_INT=0
        trap 'SUDO_INT=1' INT  # Ctrl+C ends sudo, not the installer
        sudo -v -p "${F[accent]}$G_BAR$N ${F[fg]}password for %u: " 2>&1
        rc=$?
        trap 'TUI_INT=1' INT
        TUI_INT=0
        tui_raw
        printf '\e[?25l'
        (( rc == 0 )) && { sudo_keepalive; return 0; }
        (( SUDO_INT )) && return 1
        DOC_FN=build_sudo_failed DOC_TITLE_C=${F[err]} DOC_SEL=0 DOC_HINTS=("$G_LR" choose enter confirm)
        doc_screen 4 "sudo did not work" "Try again" Back
        (( DOC_BTN == 0 )) || return 1
    done
}

build_sudo_failed() {
    d_reset
    d_text "${F[fg]}" "Either the password was wrong, or your user may not use sudo."
    d_blank
    d_text "${F[subtle]}" "To allow it, run as root (su -): usermod -aG wheel $USER_NAME, then visudo and \
remove the # in front of %wheel ALL=(ALL:ALL) ALL. Log in again afterwards."
}

build_nosudo() {
    d_reset
    d_text "${F[fg]}" "The installer needs sudo for packages, services and /etc. Install it as root: \
xbps-install sudo, and allow your user (see above)."
}

sudo_keepalive() {
    [[ -n ${SUDO_KEEP-} ]] && return 0
    ( while kill -0 "$$" 2>/dev/null; do sudo -n -v 2>/dev/null || exit; sleep 30; done ) \
        </dev/null >/dev/null 2>&1 &
    SUDO_KEEP=$!
}

# ── Running the steps ─────────────────────────────────────────────────────────────

# Reads new lines of the log (the steps write it); @@ lines are messages (lib.sh)
log_drain() {
    local line
    while :; do
        if IFS= read -r -u "$LOGRD" line; then
            line=$LOG_PART$line
            LOG_PART=""
            log_line "$line"
        else
            LOG_PART+=$line
            return 0
        fi
    done
}

log_line() {
    local l
    case $1 in
        "@@progress "*) l=${1#@@progress }; CUR_DONE=${l% *} CUR_TOTAL=${l#* } ;;
        "@@detail "*)   ST_INFO[CUR]=${1#@@detail } ;;
        "@@note "*)     NOTES+=("${1#@@note }") ;;
        "@@warn "*)     WARNINGS+=("${1#@@warn }") ;;
        "@@reboot")     REBOOT=1 ;;
        *)
            l=${1##*$'\r'}
            l=${l//$'\e'\[*([0-9;?])[@-~]/}
            l=${l//[[:cntrl:]]/}
            LOGTAIL+=("$l")
            (( ${#LOGTAIL[@]} > 400 )) && LOGTAIL=("${LOGTAIL[@]: -200}") ;;
    esac
}

# step $1 of RUN -> _ROW
step_row() {
    local i=$1 st=${RUN[$1]} g c tc info ic tw=22 iw
    case ${ST_STATE[i]} in
        ok)        g=$G_OK c=${F[ok]} tc=${F[fg]} ic=${F[muted]}
                   human_time "${ST_TIME[i]}"; info=$_HT ;;
        failed)    g=$G_FAIL c=${F[err]} tc=${F[fg]} ic=${F[err]} info="failed" ;;
        running)   g=${G_SPIN[SPIN % ${#G_SPIN[@]}]} c=${F[accent_text]} tc=$BOLD${F[fg]} ic=${F[subtle]}
                   human_time $(( SECONDS - RUN_T0 ))
                   info="${ST_INFO[i]:+${ST_INFO[i]}  }$_HT" ;;
        cancelled) g=$G_SKIP c=${F[muted]} tc=${F[muted]} ic=${F[muted]} info="not run" ;;
        *)         g=$G_PEND c=${F[muted]} tc=${F[subtle]} ic=${F[muted]} info="" ;;
    esac
    iw=$(( W - 9 - tw ))
    fit "${STEP_TITLE[$st]}" "$tw"
    local t=$_F
    fit "$info" "$iw"
    _ROW="  $c$g$N $tc$t$NOBOLD  $ic$_F$N"
}

draw_progress() {
    if (( TUI_RESIZE )); then TUI_RESIZE=0; tui_size; fi
    (( SPIN++ ))
    if tui_small; then tui_too_small; return; fi
    tui_clear
    tui_header 4
    local i st tw=0 dw=0 pct bw fill title tc bar pad ns show first n y inner bwid iw start line lc
    for i in "${!RUN[@]}"; do
        st=${RUN[i]}
        (( tw += STEP_WEIGHT[$st] * 1000 ))
        case ${ST_STATE[i]} in
            running) (( CUR_TOTAL > 0 )) && (( dw += STEP_WEIGHT[$st] * 1000 * CUR_DONE / CUR_TOTAL )) ;;
            pending) ;;
            *)       (( dw += STEP_WEIGHT[$st] * 1000 )) ;;
        esac
    done
    pct=$(( tw ? dw * 100 / tw : 100 ))
    (( pct > 100 )) && pct=100

    # title and the bar
    case $ASK in
        stop)   title="Stop after this step?"; tc=${F[warn]} ;;
        failed) title="${STEP_TITLE[${RUN[CUR]}]} failed"; tc=${F[err]} ;;
        *)      if (( ABORT )); then title="Stopping after this step"; tc=${F[warn]}
                else title="Installing"; tc=${F[fg]}; fi ;;
    esac
    bw=$(( W / 3 )); (( bw > 36 )) && bw=36
    fill=$(( pct * bw / 100 ))
    rep "$G_FILL" "$fill"; bar="${F[accent]}$_R"
    rep "$G_TRACK" $(( bw - fill )); bar+="${F[surface]}$_R$N"
    printf -v pad '%*s' $(( W - 1 - 2 - ${#title} - bw - 7 )) ''
    rfit "$pct %" 5
    FR[2]="  $tc$BOLD$title$N$pad$bar ${F[subtle]}$_F$N"

    # the steps; with too little room a window around the running one
    ns=${#RUN[@]}
    show=$(( H - 4 - 2 - 5 - 2 ))
    (( show < 3 )) && show=3
    (( show > ns )) && show=$ns
    first=$(( CUR - show / 2 ))
    (( first > ns - show )) && first=$(( ns - show ))
    (( first < 0 )) && first=0
    for (( n = 0; n < show; n++ )); do
        step_row $(( first + n ))
        FR[4 + n]=$_ROW
    done

    # the log
    y=$(( 4 + show + 1 ))
    bwid=$(( W - 4 ))
    inner=$(( H - 3 - y - 1 ))
    if (( inner >= 1 )); then
        rep "$G_HL" $(( bwid - 8 ))
        FR[y]="  ${F[overlay]}$G_TL$G_HL ${F[subtle]}log${F[overlay]} $_R$G_TR$N"
        iw=$(( bwid - 4 ))
        start=$(( ${#LOGTAIL[@]} - inner ))
        (( start < 0 )) && start=0
        for (( n = 0; n < inner; n++ )); do
            line=${LOGTAIL[start + n]-}
            case $line in
                "==> "*)                                       lc=$BOLD${F[fg]} ;;
                *ERROR*|*Error*|*error:*|*failed*|*FAILED*)    lc=${F[err]} ;;
                *WARNING*|*warning*)                           lc=${F[warn]} ;;
                *)                                             lc=${F[muted]} ;;
            esac
            fit "$line" "$iw"
            FR[y + 1 + n]="  ${F[overlay]}$G_VL $lc$_F$NOBOLD ${F[overlay]}$G_VL$N"
        done
        rep "$G_HL" $(( bwid - 2 ))
        FR[y + 1 + inner]="  ${F[overlay]}$G_BL$_R$G_BR$N"
    fi

    case $ASK in
        stop)   tui_footer y "yes, stop" n "no, go on" ;;
        failed) tui_footer r retry s "skip it" a "stop here" ;;
        *)      if (( ABORT )); then tui_footer "" "waiting for the step to end"
                else tui_footer ctrl+c "stop after this step"; fi ;;
    esac
    tui_flush
}

progress_key() {
    case $ASK in
        stop) case $KEY in y) ABORT=1; ASK="" ;; n|esc) ASK="" ;; esac ;;
        *)    [[ $KEY == @(ctrl-c|q) ]] && (( ! ABORT )) && ASK=stop ;;
    esac
}

# Runs the steps in SS with the progress screen -> ST_STATE ST_TIME, NOTES WARNINGS REBOOT
run_steps_tui() {
    local i=0 st pid rc
    RUN=("${SS[@]}")
    ST_STATE=() ST_INFO=() ST_TIME=()
    for i in "${!RUN[@]}"; do ST_STATE[i]=pending; done
    NOTES=() WARNINGS=() REBOOT=0 ABORT=0 ASK="" LOGTAIL=() LOG_PART="" CUR=0
    exec {LOGRD}<"$LOG"
    i=0
    while (( i < ${#RUN[@]} )); do
        st=${RUN[i]}
        if (( ABORT )); then ST_STATE[i]=cancelled; (( i++ )); continue; fi
        CUR=$i CUR_DONE=0 CUR_TOTAL=0 RUN_T0=$SECONDS
        ST_STATE[i]=running ST_INFO[i]=""
        printf '\n==> %s\n' "${STEP_TITLE[$st]}" >> "$LOG"
        # Background steps ignore SIGINT (bash does that for &), and SIGHUP here: closing the
        # terminal must not kill an xbps transaction halfway (the installer stops after it)
        ( trap '' HUP; "run_$st" ) </dev/null >> "$LOG" 2>&1 &
        pid=$!
        while kill -0 "$pid" 2>/dev/null; do
            log_drain
            draw_progress
            read_key 0.12 && progress_key
        done
        wait "$pid"
        rc=$?
        log_drain
        ST_TIME[i]=$(( SECONDS - RUN_T0 ))
        printf '<== %s: %s\n' "${STEP_TITLE[$st]}" "$( (( rc )) && echo "failed ($rc)" || echo ok)" >> "$LOG"
        log_drain
        if (( rc == 0 )); then ST_STATE[i]=ok; (( i++ )); continue; fi
        ST_STATE[i]=failed
        ASK=failed
        while :; do
            draw_progress
            read_key 0.5 || continue
            case $KEY in
                r)                ASK=""; continue 2 ;;
                s|enter)          ASK=""; (( i++ )); continue 2 ;;
                a|q|esc|ctrl-c)   ASK=""; ABORT=1; (( i++ )); continue 2 ;;
            esac
        done
    done
    exec {LOGRD}<&-
}

# ── The end ───────────────────────────────────────────────────────────────────────

build_done() {
    local i n=0 l k
    d_reset
    for i in "${!RUN[@]}"; do
        step_row "$i"
        DL+=("${_ROW:2}")
        [[ ${ST_STATE[i]} == failed ]] && (( n++ ))
    done
    d_blank
    d_head "Next"
    PLAN=()
    if (( n || ABORT )); then
        PLAN+=("Run ./install.sh again to finish: steps that are done are skipped, the rest runs again.")
        (( n )) && PLAN+=("What went wrong is in the log (below).")
    fi
    if (( REBOOT )); then
        PLAN+=("Restart the computer: new services, groups and the login shell take effect then.")
    elif [[ $FLOW == links ]]; then
        PLAN+=("Reload i3 and Polybar with Alt+Shift+r; programs that are open pick the theme up on their next start.")
    elif (( IN_X && ! n && ! ABORT )); then
        PLAN+=("Log out of this session and start X again: .xinitrc sets up the new one.")
    fi
    if [[ $FLOW != links ]] && (( ! n && ! ABORT )); then
        if (( SEL[autostart] )); then PLAN+=("Log in on tty1: X starts by itself.")
        elif [[ -z $DM ]]; then PLAN+=("Start the desktop with startx after logging in."); fi
    fi
    PLAN+=("${NOTES[@]}")
    for l in "${WARNINGS[@]}"; do PLAN+=("!$l"); done
    d_plan
    d_blank
    d_kv Log "${LOG/#$HOME/\~}" "${F[fg]}" 6
    if [[ $FLOW != links ]] && (( n == 0 && ! ABORT )); then
        local keys=("Alt+Return" terminal "Alt+d" launcher "Alt+Shift+e" "power menu: lock, log out, reboot"
                    "Super+l" "lock the screen" "dotfiles.conf" "colors, fonts, sizes; then: dotfiles apply")
        d_blank
        d_head "In the new desktop"
        for (( k = 0; k < ${#keys[@]}; k += 2 )); do
            d_kv "${keys[k]}" "${keys[k + 1]}" "${F[fg]}" 15
        done
    fi
    DONE_PROBLEMS=$n
}

screen_done() {
    local title btns=(Exit)
    DOC_FN=build_done
    DW=$(( W - 7 )); build_done
    if (( DONE_PROBLEMS )); then
        title="$G_FAIL Finished: $DONE_PROBLEMS step$( (( DONE_PROBLEMS > 1 )) && echo s) did not work"
        DOC_TITLE_C=${F[err]}
    elif (( ABORT )); then title="Stopped"; DOC_TITLE_C=${F[warn]}
    else title="$G_OK Done"; DOC_TITLE_C=${F[ok]}; fi
    (( REBOOT )) && btns=(Exit "Reboot now")
    DOC_SEL=0 DOC_HINTS=("$G_LR" choose enter confirm j/k scroll)
    doc_screen 4 "$title" "${btns[@]}"
    (( DOC_BTN == 1 )) && WANT_REBOOT=1
    return 0
}

# ── Flow ──────────────────────────────────────────────────────────────────────────

tui_main() {
    tui_start || return 1
    tui_splash "Looking at this machine"
    scan_machine
    HDR_SYS="$OS_NAME $ARCH"
    HDR_GPU=${GPU_NAMES[0]-}
    HDR_USER="$USER_NAME@$HOST_NAME"
    while :; do
        screen_main
        case $LS_OUT in
            complete) mods_default; FLOW=complete; flow_install ;;
            modules)  FLOW=modules; flow_install ;;
            links)    FLOW=links; flow_links ;;
            *)        return 0 ;;
        esac
        (( FLOW_DONE )) && return 0
    done
}

flow_install() {
    local rc
    PLAN_TITLE="What happens" PLAN_ACTION=Install
    while :; do
        if [[ $FLOW == modules ]]; then
            screen_modules
            case $LS_OUT in back) return 0 ;; quit) exit 0 ;; esac
        elif (( GPU_NVIDIA && SEL[graphics] && ${#NVIDIA_DRIVERS[@]} > 1 )) && [[ -z ${NV_ASKED-} ]]; then
            screen_nvidia
            case $LS_OUT in back) return 0 ;; quit) exit 0 ;; esac
            NV_ASKED=1
        fi
        screen_plan
        rc=$?
        (( rc == 0 )) && break
        (( rc == 2 )) && exit 0
        [[ $FLOW == complete ]] && { NV_ASKED=""; return 0; }
    done
    run_install
}

flow_links() {
    local m
    for m in "${MODULES[@]}"; do SEL[$m]=0; done
    SEL[core]=1
    PLAN_TITLE="Update links" PLAN_ACTION=Update
    SM=()
    SS=(links theme)
    tui_splash "Working out the plan" 3
    TX_COUNT=0 TX_UNKNOWN=()
    DOC_FN=build_plan DOC_TITLE_C="" DOC_SEL=0
    DOC_HINTS=("$G_LR" choose enter confirm esc back)
    doc_screen 3 "Update links" Update Back
    case $DOC_BTN in 0) ;; -2) exit 0 ;; *) mods_default; return 0 ;; esac
    log_header
    run_steps_tui
    screen_done
    FLOW_DONE=1
}

run_install() {
    log_header
    if sel_needs_root; then tui_sudo || return 0; fi
    run_steps_tui
    screen_done
    FLOW_DONE=1
}
