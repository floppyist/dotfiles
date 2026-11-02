# shellcheck shell=bash
# kernelforge/lib/source.sh  ·  which kernel version, and the source from kernel.org: downloaded
# over https, the signature of the tarball checked against pinned developer keys.

KERNEL_ORG=https://cdn.kernel.org/pub/linux/kernel

# Primary key fingerprints of the people who sign kernel tarballs (kernel.org, "Signatures"):
# Linus Torvalds, Greg Kroah-Hartman, Sasha Levin
SIGNER_FPRS=(
    ABAF11C65A2970B130ABE3C479BE3E4300411886
    647F28654894E3BD457199BE38DBBDC86092693E
    E27E5D8A3403A2EF66873BBCDEA66FF797772CDC
)

valid_version() {
    [[ $1 =~ ^([0-9]+)\.[0-9]+(\.[0-9]+)?$ ]] && (( BASH_REMATCH[1] >= 4 ))
}

# The versions kernel.org lists as maintained -> RELEASES ("VERSION KIND" per element). Without
# python: the installer asks for them before any package is installed. Every release has one
# "moniker" and one "version" (in either order); the nested objects have neither.
kernel_releases() {
    RELEASES=()
    local json v m
    json=$(curl_get --max-time 60 https://www.kernel.org/releases.json 2>/dev/null) || return 1
    while read -r v m; do
        [[ $v =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ && $m =~ ^(mainline|stable|longterm)$ ]] && RELEASES+=("$v $m")
    done < <(grep -oE '"(moniker|version)"[[:space:]]*:[[:space:]]*"[^"]*"' <<< "$json" | tr -d '"' |
             awk -F '[[:space:]]*:[[:space:]]*' '
                 $1 == "moniker" { m = $2 } $1 == "version" { v = $2 }
                 m != "" && v != "" { print v, m; m = v = "" }')
    (( ${#RELEASES[@]} ))
}

# The version nobody chose: the newest of the running series, else exactly the running version
default_version() {
    local r v
    for r in "${RELEASES[@]}"; do
        v=${r%% *}
        [[ $v == "$SERIES" || $v == "$SERIES".* ]] && { echo "$v"; return; }
    done
    echo "$CUR_VER"
}

resolve_version() {
    if [[ -n ${KF_VERSION-} ]]; then
        valid_version "$KF_VERSION" || die "invalid version '$KF_VERSION' (like 6.18.60)"
        return
    fi
    if ! kernel_releases; then
        warn "kernel.org did not answer: using the running version $CUR_VER"
        KF_VERSION=$CUR_VER
        return
    fi
    KF_VERSION=$(default_version)
    if (( ! KF_NONINTERACTIVE )) && [[ -t 0 && -t 1 && ${KF_YES:-0} != 1 ]]; then choose_version; fi
}

# A numbered list on the terminal; Enter takes the default
choose_version() {
    local i=1 r sel items=()
    say ""
    say "Kernel versions (the running one is $CUR_VER):"
    for r in "${RELEASES[@]}"; do
        items+=("${r%% *}")
        printf '  %d) %-10s %s%s\n' "$i" "${r%% *}" "${r#* }" "$([[ ${r%% *} == "$KF_VERSION" ]] && echo '  (default)')"
        (( i++ ))
    done
    read -r -p "Version, a number or like 6.18.60 [$KF_VERSION]: " sel
    [[ -z $sel ]] && return 0
    if [[ $sel =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#items[@]} )); then KF_VERSION=${items[sel-1]}
    elif valid_version "$sel"; then KF_VERSION=$sel
    else die "invalid choice '$sel'"; fi
}

# ── Download, verify, unpack ──────────────────────────────────────────────────────

# $1 tarball, $2 signature. The signature is over the .tar, not the .tar.xz.
verify_signature() {
    local tar=$1 sig=$2 out good valid f
    mktmp; local gh=$MKTMP
    export GNUPGHOME=$gh
    # the keys: through the web key directory of kernel.org, else a key server; either way only
    # a signature by one of the pinned fingerprints counts
    if ! gpg --batch --no-tty --quiet --auto-key-locate clear,wkd --locate-keys \
            torvalds@kernel.org gregkh@kernel.org sashal@kernel.org >> "$LOGFILE" 2>&1; then
        gpg --batch --no-tty --quiet --keyserver hkps://keys.openpgp.org \
            --recv-keys "${SIGNER_FPRS[@]}" >> "$LOGFILE" 2>&1 || true
    fi
    out=$(gpg --batch --no-tty --status-fd 1 --verify "$sig" "$tar" 2>> "$LOGFILE")
    unset GNUPGHOME
    log_file "$out"
    # VALIDSIG <fingerprint> <8 fields> <fingerprint of the primary key>
    good=$(awk '$1 == "[GNUPG:]" && $2 == "GOODSIG" {print "1"; exit}' <<< "$out")
    valid=$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {print $NF; exit}' <<< "$out")
    GNUPGHOME=$gh gpgconf --kill all 2>/dev/null
    [[ -n $good && -n $valid ]] || return 1
    for f in "${SIGNER_FPRS[@]}"; do [[ $valid == "$f" ]] && return 0; done
    warn "signed by an unknown key: $valid"
    return 1
}

fetch_source() {
    local v=$KF_VERSION major url dl="$CACHE/dl" src="$CACHE/src" f t
    major=${v%%.*}
    url=$KERNEL_ORG/v$major.x/linux-$v
    K_SRC=$src/linux-$v
    step "Source: Linux $v"
    if [[ -f $K_SRC/.kernelforge-verified ]]; then
        ok "already unpacked and verified: $K_SRC"
        return
    fi
    mkdir -p "$dl" "$src" || die "cannot create $dl"
    (( $(free_bytes "$CACHE") >= 5 * 1073741824 )) || die "less than 5 GB free in $CACHE"

    for f in tar.xz tar.sign; do
        [[ -s $dl/linux-$v.$f ]] && continue
        detail "downloading linux-$v.$f"
        say "downloading $url.$f"
        curl_get --max-time 1800 -o "$dl/linux-$v.$f.part" "$url.$f" \
            || { rm -f "$dl/linux-$v.$f.part"; die "download failed: $url.$f (does version $v exist?)"; }
        mv -f "$dl/linux-$v.$f.part" "$dl/linux-$v.$f"
    done

    detail "unpacking the archive"
    t=$dl/linux-$v.tar
    xz -dc "$dl/linux-$v.tar.xz" > "$t.part" || { rm -f "$t.part" "$dl/linux-$v.tar.xz"; die "xz failed: broken download removed, run it again"; }
    mv -f "$t.part" "$t"

    detail "checking the signature"
    say "checking the signature (Torvalds, Kroah-Hartman, Levin)"
    if ! verify_signature "$t" "$dl/linux-$v.tar.sign"; then
        rm -f "$t" "$dl/linux-$v.tar.xz" "$dl/linux-$v.tar.sign"
        die "the signature of linux-$v.tar is not valid: download removed"
    fi
    ok "signature valid"

    detail "extracting"
    mktmp "$src"; local x=$MKTMP
    # GNU tar refuses absolute names and .. by default
    tar -xf "$t" -C "$x" --no-same-owner || { rm -f "$t"; die "extracting failed"; }
    rm -f "$t"
    [[ -f $x/linux-$v/Makefile ]] || die "the archive has no linux-$v/Makefile"
    : > "$x/linux-$v/.kernelforge-verified"
    rm -rf -- "$K_SRC"
    mv -- "$x/linux-$v" "$K_SRC"
    ok "source: $K_SRC"
}
