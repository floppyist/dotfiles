# shellcheck shell=bash
# install/upstream.sh  ·  programs a distribution does not package, or only in a version too old
# for this desktop (install/pkgmap.sh: @bin:NAME, @src:NAME). Versions and SHA-256 sums are pinned:
#   bin  the release binary of the project, unpacked into ~/.local/opt/NAME-VERSION and linked into
#        ~/.local/bin (no root; ~/.local/bin comes first in PATH)
#   src  the source tarball, built as the user in ~/.cache/dotfiles/build, then `make install`
#        into /usr/local (root). Its build dependencies come from the distribution (UP_DEPS).
# A stamp in ~/.local/state/dotfiles/upstream/NAME holds the installed version.

declare -A UP_KIND UP_VER UP_URL UP_SHA UP_DEPS UP_CHECK UP_LINK

UP_DIR=$HOME/.local/opt
UP_BUILD=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/build
UP_STAMPS=$STATE_DIR/upstream

# fzf: --gutter (the rofi look) needs 0.66
UP_KIND[fzf]=bin UP_VER[fzf]=0.74.5 UP_LINK[fzf]=fzf
UP_URL[fzf:x86_64]=https://github.com/junegunn/fzf/releases/download/v0.74.5/fzf-0.74.5-linux_amd64.tar.gz
UP_SHA[fzf:x86_64]=d47d7f882972c7d674dbbba998ffa4116e68379616ffac7695d0671e9a722c5f
UP_URL[fzf:aarch64]=https://github.com/junegunn/fzf/releases/download/v0.74.5/fzf-0.74.5-linux_arm64.tar.gz
UP_SHA[fzf:aarch64]=cf058001da21724a469b714a29cf4aab9cbe860d218a0d6c1b5b661efad7784c

# Neovim: LazyVim needs 0.11.2 (glibc builds)
UP_KIND[neovim]=bin UP_VER[neovim]=0.12.6 UP_LINK[neovim]=nvim
UP_URL[neovim:x86_64]=https://github.com/neovim/neovim/releases/download/v0.12.6/nvim-linux-x86_64.tar.gz
UP_SHA[neovim:x86_64]=474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
UP_URL[neovim:aarch64]=https://github.com/neovim/neovim/releases/download/v0.12.6/nvim-linux-arm64.tar.gz
UP_SHA[neovim:aarch64]=8f1f64a0bdb97247034038c3823c6cbad5bdf9ecd5751b85494b71c3ee04c815

# tree-sitter CLI: nvim-treesitter builds its parsers with it (0.25 or newer)
UP_KIND[tree-sitter]=bin UP_VER[tree-sitter]=0.27.1 UP_LINK[tree-sitter]=tree-sitter
UP_URL[tree-sitter:x86_64]=https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.1/tree-sitter-linux-x64.gz
UP_SHA[tree-sitter:x86_64]=d01042f94ba3d6827ddc9788e235f75d8366431be42bdf90ade534d960c98b7d
UP_URL[tree-sitter:aarch64]=https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.1/tree-sitter-linux-arm64.gz
UP_SHA[tree-sitter:aarch64]=404be5d54a4955571c4067c21d4699660eab3a534cefb0659341b207f7139ec5

# i3lock-color: the lock screen (plain i3lock lacks the clock, the bar indicator and the texts)
UP_KIND[i3lock-color]=src UP_VER[i3lock-color]=2.13.c.5 UP_CHECK[i3lock-color]=/usr/local/bin/i3lock
UP_URL[i3lock-color]=https://github.com/Raymo111/i3lock-color/archive/refs/tags/2.13.c.5.tar.gz
UP_SHA[i3lock-color]=46f15cbbf339873266e014f70b5e1ec02177f0295302b615a7bd85bef40d8ad2
UP_DEPS[arch:i3lock-color]="autoconf automake gcc make pkgconf cairo fontconfig libev libjpeg-turbo libxinerama libxkbcommon-x11 libxrandr pam xcb-util-image xcb-util-xrm"
UP_DEPS[debian:i3lock-color]="autoconf automake gcc make pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util0-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev libgif-dev"
UP_DEPS[ubuntu:i3lock-color]=${UP_DEPS[debian:i3lock-color]}
UP_DEPS[fedora:i3lock-color]="autoconf automake gcc make pkgconf-pkg-config cairo-devel fontconfig-devel libev-devel libjpeg-turbo-devel libXinerama-devel libxkbcommon-devel libxkbcommon-x11-devel libXrandr-devel pam-devel xcb-util-image-devel xcb-util-xrm-devel giflib-devel libX11-devel xcb-util-devel"

# xss-lock (Alpine): locks the screen when idle and before suspend
UP_KIND[xss-lock]=src UP_VER[xss-lock]=0.3.0 UP_CHECK[xss-lock]=/usr/local/bin/xss-lock
UP_URL[xss-lock]=https://github.com/xdbob/xss-lock/archive/refs/tags/v0.3.0.tar.gz
UP_SHA[xss-lock]=2beb7d05991b4fba341dcdf2d8160253e694a7ee47eb2eb0eade59dd5ce7ca18
UP_DEPS[alpine:xss-lock]="cmake make gcc musl-dev pkgconf glib-dev libxcb-dev xcb-util-dev"

# xbanish (Arch: only in the AUR): hides the pointer while typing
UP_KIND[xbanish]=src UP_VER[xbanish]=1.8 UP_CHECK[xbanish]=/usr/local/bin/xbanish
UP_URL[xbanish]=https://github.com/jcs/xbanish/archive/refs/tags/v1.8.tar.gz
UP_SHA[xbanish]=e753d6a92d17105ad0d374f0349579b7e7bb070d4bebf5ec28ea105cb0c5b507
UP_DEPS[arch:xbanish]="gcc make pkgconf libx11 libxfixes libxi libxt"

# The machine's architecture in the names above -> _UA (empty: no release binaries)
up_arch() {
    case $(uname -m) in
        x86_64) _UA=x86_64 ;; aarch64|arm64) _UA=aarch64 ;; *) _UA="" ;;
    esac
}

up_url() {
    if [[ ${UP_KIND[$1]} == bin ]]; then
        up_arch
        _UURL=${UP_URL[$1:$_UA]-} _USHA=${UP_SHA[$1:$_UA]-}
    else
        _UURL=${UP_URL[$1]} _USHA=${UP_SHA[$1]}
    fi
}

# Installed in the pinned version
up_have() {
    local v=""
    [[ -n ${UP_KIND[$1]-} ]] || return 1
    read -r v 2>/dev/null < "$UP_STAMPS/$1"
    [[ $v == "${UP_VER[$1]}" ]] || return 1
    if [[ ${UP_KIND[$1]} == bin ]]; then
        [[ -x $HOME/.local/bin/${UP_LINK[$1]} ]]
    else
        [[ -x ${UP_CHECK[$1]} ]]
    fi
}

# Build dependencies of the upstream programs $@ that are not installed -> _UD
up_deps() {
    local n p
    _UD=()
    for n in "$@"; do
        [[ ${UP_KIND[$n]-} == src ]] || continue
        up_have "$n" && continue
        for p in ${UP_DEPS[$DISTRO:$n]-}; do pkg_have "$p" || _UD+=("$p"); done
    done
}

up_title() {
    if [[ ${UP_KIND[$1]} == bin ]]; then
        _UT="download $1 ${UP_VER[$1]} (release binary, SHA-256 checked) into ~/.local/opt"
    else
        _UT="build $1 ${UP_VER[$1]} from its source (SHA-256 checked), install it into /usr/local"
    fi
}

# Downloads $_UURL to $1 and checks it against $_USHA
up_fetch() {
    local sum _
    curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 20 -o "$1" "$_UURL" || return 1
    read -r sum _ < <(sha256sum "$1")
    if [[ $sum != "$_USHA" ]]; then
        say "SHA-256 of $_UURL does not match: $sum (expected $_USHA)"
        rm -f "$1"
        return 1
    fi
}

up_install_bin() {
    local n=$1 v=${UP_VER[$1]} tmp dest link old
    up_url "$n"
    [[ -n $_UURL ]] || { warn "$n: no release binary for $(uname -m); install it yourself"; return 1; }
    link=$HOME/.local/bin/${UP_LINK[$n]}
    if [[ -e $link && ! -L $link ]]; then
        warn "$link is a file of yours: $n ${UP_VER[$n]} is not linked over it"
        return 1
    fi
    tmp=$(mktemp -d) || return 1
    detail "downloading $n $v"
    up_fetch "$tmp/dl" || { rm -rf "$tmp"; return 1; }
    dest=$UP_DIR/$n-$v
    rm -rf "$dest.new"
    mkdir -p "$dest.new" || { rm -rf "$tmp"; return 1; }
    case $n in
        fzf)         tar -xzf "$tmp/dl" -C "$dest.new" fzf ;;
        neovim)      tar -xzf "$tmp/dl" -C "$dest.new" --strip-components=1 ;;
        tree-sitter) gzip -dc "$tmp/dl" > "$dest.new/tree-sitter" && chmod 755 "$dest.new/tree-sitter" ;;
    esac || { rm -rf "$tmp" "$dest.new"; return 1; }
    rm -rf "$tmp" "$dest"
    mv "$dest.new" "$dest" || return 1
    mkdir -p "$HOME/.local/bin" || return 1
    case $n in neovim) ln -sfn "$dest/bin/nvim" "$link" ;; *) ln -sfn "$dest/${UP_LINK[$n]}" "$link" ;; esac || return 1
    # older versions of ours
    for old in "$UP_DIR/$n"-*; do [[ $old != "$dest" && -d $old ]] && rm -rf "$old"; done
    say "installed $n $v: $link"
}

up_install_src() {
    local n=$1 v=${UP_VER[$1]} dir rc jobs
    up_url "$n"
    mkdir -p "$UP_BUILD" || return 1
    dir=$UP_BUILD/$n-$v
    rm -rf "$dir" "$dir.tar.gz"
    detail "downloading $n $v"
    up_fetch "$dir.tar.gz" || return 1
    mkdir -p "$dir" && tar -xzf "$dir.tar.gz" -C "$dir" --strip-components=1 || return 1
    rm -f "$dir.tar.gz"
    jobs=$(nproc 2>/dev/null || echo 2)
    detail "building $n $v"
    (
        cd "$dir" || exit 1
        case $n in
            i3lock-color)
                autoreconf -fi && mkdir -p build && cd build &&
                    ../configure --prefix=/usr/local --sysconfdir=/etc --disable-sanitizers &&
                    make -j"$jobs" ;;
            xss-lock)
                cmake -B build -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_POLICY_VERSION_MINIMUM=3.5 &&
                    make -C build -j"$jobs" ;;
            xbanish)
                make -j"$jobs" ;;
        esac
    ) 2>&1 || { say "building $n failed"; return 1; }
    detail "installing $n $v into /usr/local"
    case $n in
        i3lock-color) as_root make -C "$dir/build" install 2>&1 ;;
        xss-lock)     as_root make -C "$dir/build" install 2>&1 ;;
        xbanish)      as_root make -C "$dir" PREFIX=/usr/local install 2>&1 ;;
    esac
    rc=$?
    (( rc == 0 )) || return "$rc"
    rm -rf "$dir"
    say "installed $n $v into /usr/local"
}

# ── The step ──────────────────────────────────────────────────────────────────────

plan_upstream() {
    local n
    PLAN=()
    for n in "${SU[@]}"; do
        up_have "$n" && continue
        up_title "$n"
        PLAN+=("$_UT")
    done
    (( ${#PLAN[@]} ))
}

run_upstream() {
    local n failed=0
    mkdir -p "$UP_STAMPS" || return 1
    for n in "${SU[@]}"; do
        if up_have "$n"; then say "$n ${UP_VER[$n]} is installed"; continue; fi
        if [[ ${UP_KIND[$n]} == bin ]]; then up_install_bin "$n"; else up_install_src "$n"; fi || {
            warn "$n ${UP_VER[$n]} could not be installed (see the log)"
            failed=1
            continue
        }
        printf '%s\n' "${UP_VER[$n]}" > "$UP_STAMPS/$n"
    done
    return "$failed"
}
