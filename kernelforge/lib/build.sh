# shellcheck shell=bash
# kernelforge/lib/build.sh  ·  what the build needs, the build, the modules in a staging directory.
# Everything here runs as your user: root is for the installation (boot.sh) only.

# Missing tools -> MISSING (names of the commands); libraries are tested with the compiler
check_build_tools() {
    local c
    MISSING=()
    for c in gcc make flex bison bc perl xz gzip tar curl gpg python3 depmod; do
        command -v "$c" >/dev/null || MISSING+=("$c")
    done
    if command -v gcc >/dev/null; then
        echo '#include <openssl/ssl.h>' | gcc -E -x c - >/dev/null 2>&1 || MISSING+=("openssl headers")
        echo '#include <gelf.h>' | gcc -E -x c - >/dev/null 2>&1 || MISSING+=("libelf headers")
    fi
    # pahole: without it a kernel with BTF would silently lose it (BPF programs)
    if zcat /proc/config.gz 2>/dev/null | grep -q '^CONFIG_DEBUG_INFO_BTF=y'; then
        command -v pahole >/dev/null || MISSING+=(pahole)
    fi
    (( ${#MISSING[@]} == 0 ))
}

# One compile job per GB of free memory, at most one per thread
build_jobs() {
    local kb jobs
    kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    [[ $kb =~ ^[0-9]+$ ]] || kb=4194304
    jobs=$(( kb / 1048576 )); (( jobs < 1 )) && jobs=1
    (( jobs > CPU_THREADS )) && jobs=$CPU_THREADS
    JOBS=${KF_JOBS:-$jobs}
}

build_kernel() {
    local line n=0 total pct last=-1 rc

    step "Build"
    build_jobs
    [[ $(free_bytes "$CACHE") -ge $(( 5 * 1073741824 )) ]] || die "less than 5 GB free in $CACHE"

    # About 2.3 compile steps per enabled option (measured: 4600 steps for 2300 options). Only
    # for the progress bar: it is raised when the estimate is too low.
    total=$(grep -cE '^CONFIG_.*=(y|m)$' "$K_OUT/.config")
    total=$(( total * 23 / 10 )); (( total < 500 )) && total=500
    info "about $total compile steps, $JOBS jobs (nice 10)"

    detail "building"
    kmake -j"$JOBS" bzImage modules 2>&1 | while IFS= read -r line; do
        printf '%s\n' "$line" >> "$LOGFILE"
        case $line in
            "  CC "*|"  CC["*|"  AS "*|"  AS["*)
                (( n++ ))
                (( n * 100 > total * 95 )) && total=$(( n * 100 / 95 + 1 ))
                pct=$(( n * 100 / total )); (( pct > 99 )) && pct=99
                if (( pct != last )); then last=$pct; progress "$pct" 100; detail "building: ${line##* } ($pct %)"; fi ;;
            *": error"*|*": fatal error"*|*"] Error "*) printf '%s\n' "$(clean "$line")" ;;
        esac
    done
    rc=${PIPESTATUS[0]}
    if (( rc )); then
        tail -n 25 "$LOGFILE" >&2
        die "the build failed ($rc), see $LOGFILE"
    fi
    [[ -f $K_OUT/arch/x86/boot/bzImage ]] || die "no bzImage after the build"
    progress 100 100
    ok "build finished"

    detail "collecting the modules"
    STAGE=$K_OUT/stage
    rm -rf -- "$STAGE"
    run_logged kmake INSTALL_MOD_PATH="$STAGE" INSTALL_MOD_STRIP=1 modules_install || die "modules_install failed"
    [[ -d $STAGE/lib/modules/$K_REL ]] || die "no modules in $STAGE/lib/modules/$K_REL"
    # the links into the build directory would break when it is cleaned up
    rm -f -- "$STAGE/lib/modules/$K_REL/build" "$STAGE/lib/modules/$K_REL/source"
    ok "modules: $(du -sh "$STAGE/lib/modules/$K_REL" | cut -f1)"
}
