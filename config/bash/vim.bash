# vim.bash  ·  vim text objects for bash's vi mode (sourced by ~/.bashrc)
#
# Readline's vi mode already has the motions, the operators c d y, counts, p/P, u and `.`.
# This adds the text objects it lacks. In normal mode, after c (change), d (delete) or
# y (yank; p pastes it):
#
#   iw aw  word             iW aW  WORD (everything up to the next blank)
#   i" a"  "string"         i' a'  'string'         i` a`  `command`
#   i( a(  (...), also ib   i[ a[  [...]            i{ a{  {...}, also iB    i< a<  <...>
#
# e.g. ciw, da", yi(. A quote object is the string under the cursor or the next one on the
# line, a bracket object the innermost pair around the cursor. Without such an object d and y
# do nothing, c enters insert mode at the cursor (vim would stay in normal mode). `v` (readline's own) opens
# the line in $VISUAL: full vim with visual mode, the command runs when you save and quit.
#
# How it works: "diw" is a readline macro. Its first key runs _vim_select (bind -x), which
# marks the object (point = start, mark = end); readline's own kill-region then deletes it,
# so the text is in the kill ring (p) and u undoes it. "y..." uses copy-region-as-kill.
# "c..." continues with `i` and then puts the cursor back where the object was (normal
# mode moves a cursor at the end of the line onto the last character, insert mode does
# not). keyseq-timeout 0 (~/.inputrc) makes readline wait for the last key instead of
# running a plain `c`/`d`/`y` after half a second.
# Cost: plain string operations when such a key is typed, nothing per prompt or keystroke.

# _vim_select i|a OBJECT  (OBJECT: w W dq sq bq paren bracket brace angle)
_vim_select() {
    local line=$READLINE_LINE p=$READLINE_POINT n=${#READLINE_LINE} s=-1 e=-1
    if ((n > 0)); then
        ((p >= n)) && p=$((n - 1))
        case $2 in
            w | W) _vim_word "$1" "$2" ;;
            dq) _vim_quote "$1" '"' ;;
            sq) _vim_quote "$1" "'" ;;
            bq) _vim_quote "$1" '`' ;;
            paren) _vim_pair "$1" '(' ')' ;;
            bracket) _vim_pair "$1" '[' ']' ;;
            brace) _vim_pair "$1" '{' '}' ;;
            angle) _vim_pair "$1" '<' '>' ;;
        esac
    fi
    if ((s >= 0)); then
        READLINE_POINT=$s READLINE_MARK=$e
    else
        # nothing found: an empty region, the kill after it does nothing
        READLINE_MARK=$READLINE_POINT
    fi
    _vim_at=$READLINE_POINT
}

# Insert mode after "c...": the cursor goes to where the object started
_vim_insert_at() { READLINE_POINT=${_vim_at:-$READLINE_POINT}; }

# Character class at index $1 into `cls`: 0 blank, 1 punctuation, 2 word character
# (letters, digits, _). For WORD objects ($big set) everything that is not blank is 1.
_vim_class() {
    local c=${line:$1:1}
    if [[ $c == [[:blank:]] ]]; then
        cls=0
    elif [[ -n $big || $c != [[:alnum:]_] ]]; then
        cls=1
    else
        cls=2
    fi
}

# Extend s backwards / e forwards over blanks
_vim_blanks_after() { while ((e < n)) && [[ ${line:e:1} == [[:blank:]] ]]; do ((e++)); done; }
_vim_blanks_before() { while ((s > 0)) && [[ ${line:s-1:1} == [[:blank:]] ]]; do ((s--)); done; }

# aw/a"/a(: like vim, the blanks after the object, or the ones before it if there are none after
_vim_around_blanks() {
    local end=$e
    _vim_blanks_after
    ((e == end)) && _vim_blanks_before
}

_vim_word() {
    local big="" cls first
    [[ $2 == W ]] && big=1
    _vim_class "$p"
    first=$cls
    s=$p e=$((p + 1))
    while ((s > 0)); do _vim_class $((s - 1)); ((cls == first)) || break; ((s--)); done
    while ((e < n)); do _vim_class "$e"; ((cls == first)) || break; ((e++)); done
    [[ $1 == a ]] || return 0
    if ((first == 0)); then
        # on blanks: the blanks and the word after them
        if ((e < n)); then
            _vim_class "$e"
            first=$cls
            while ((e < n)); do _vim_class "$e"; ((cls == first)) || break; ((e++)); done
        fi
    else
        _vim_around_blanks
    fi
}

# Quote objects: quotes pair up from the start of the line; a backslash escapes a quote
_vim_quote() {
    local q=$2 i c open=-1 close=-1
    local -a pos=()
    for ((i = 0; i < n; i++)); do
        c=${line:i:1}
        if [[ $c == '\' ]]; then
            ((i++))
        elif [[ $c == "$q" ]]; then
            pos+=("$i")
        fi
    done
    # the first pair that ends at or after the cursor: the one around it, or the next one
    for ((i = 0; i + 1 < ${#pos[@]}; i += 2)); do
        if ((p <= pos[i + 1])); then
            open=${pos[i]} close=${pos[i + 1]}
            break
        fi
    done
    ((open >= 0)) || return 0
    if [[ $1 == i ]]; then
        s=$((open + 1)) e=$close
    else
        s=$open e=$((close + 1))
        _vim_around_blanks
    fi
}

# Bracket objects: the innermost pair around the cursor (or starting/ending at it)
_vim_pair() {
    local open=$2 close=$3 i c depth=0 o=-1 x=-1
    if [[ ${line:p:1} == "$open" ]]; then
        o=$p
    else
        for ((i = p - 1; i >= 0; i--)); do
            c=${line:i:1}
            if [[ $c == "$close" ]]; then
                ((depth++))
            elif [[ $c == "$open" ]]; then
                ((depth == 0)) && { o=$i; break; }
                ((depth--))
            fi
        done
    fi
    ((o >= 0)) || return 0
    depth=0
    for ((i = o + 1; i < n; i++)); do
        c=${line:i:1}
        if [[ $c == "$open" ]]; then
            ((depth++))
        elif [[ $c == "$close" ]]; then
            ((depth == 0)) && { x=$i; break; }
            ((depth--))
        fi
    done
    ((x >= 0)) || return 0
    if [[ $1 == i ]]; then
        s=$((o + 1)) e=$x
    else
        s=$o e=$((x + 1))
    fi
}

_vim_bind() {
    local -A objects=(
        [w]=w [W]=W ['"']=dq ["'"]=sq ['`']=bq
        ['(']=paren [')']=paren [b]=paren ['[']=bracket [']']=bracket
        ['{']=brace ['}']=brace [B]=brace ['<']=angle ['>']=angle
    )
    local key k seq
    # Hidden key sequences that the macros below type (Ctrl+x prefix)
    bind -m vi-command '"\C-x\C-k": kill-region'
    bind -m vi-command '"\C-x\C-w": copy-region-as-kill'
    bind -m vi-insert -x '"\C-x\C-p": _vim_insert_at'
    for key in "${!objects[@]}"; do
        for k in i a; do
            seq=$k${key/'"'/'\"'}
            bind -m vi-command -x "\"\\C-x\\C-v$seq\": _vim_select $k ${objects[$key]}"
            bind -m vi-command "\"d$seq\": \"\\C-x\\C-v$seq\\C-x\\C-k\""
            bind -m vi-command "\"c$seq\": \"\\C-x\\C-v$seq\\C-x\\C-ki\\C-x\\C-p\""
            bind -m vi-command "\"y$seq\": \"\\C-x\\C-v$seq\\C-x\\C-w\""
        done
    done
}
_vim_bind
unset -f _vim_bind
