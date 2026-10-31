# shellcheck shell=bash
# kernelforge/lib/config.sh  ·  the configuration: the running kernel's, reduced to the modules
# that are loaded now (localmodconfig), plus a few safety nets.

KF_SUFFIX=-kf

# Modules that are not loaded all the time but that you will want: localmodconfig would remove
# them. Each one stays a module if the running kernel has it as a module. More: --keep SYMBOL.
KEEP_DEFAULT=(
    USB_STORAGE USB_UAS USB_ACM USB_SERIAL SND_USB_AUDIO
    FAT_FS VFAT_FS EXFAT_FS NTFS3_FS ISO9660_FS UDF_FS FUSE_FS OVERLAY_FS SQUASHFS
    TUN WIREGUARD UINPUT BT BT_BNEP BT_RFCOMM BT_HIDP
)

# make in the kernel source with the output in $K_OUT. The environment of a login shell
# (CFLAGS, ARCH, ...) must not change the kernel build.
kmake() {
    env -u MAKEFLAGS -u CFLAGS -u CPPFLAGS -u CXXFLAGS -u LDFLAGS -u ARCH -u CROSS_COMPILE -u KCONFIG_CONFIG \
        LC_ALL=C nice -n 10 make -C "$K_SRC" O="$K_OUT" "$@"
}

kcfg() { "$K_SRC/scripts/config" --file "$K_OUT/.config" "$@"; }

# CONFIG_$1 of a config file: y, m or empty
cfg_value() { sed -n "s/^CONFIG_$1=//p" "$2" | head -1; }

config_generate() {
    local sym v n base

    step "Configuration"
    K_OUT=$CACHE/build/$KF_VERSION
    mkdir -p "$K_OUT" || die "cannot create $K_OUT"
    base=$K_OUT/.config.base
    read_running_config "$base"
    info "base: $BASE_CONFIG"
    cp -- "$base" "$K_OUT/.config"

    detail "adapting the configuration to $KF_VERSION"
    run_logged kmake olddefconfig || die "olddefconfig failed"

    if (( KF_LOCALMOD )); then
        detail "reducing to the loaded modules"
        lsmod > "$K_OUT/lsmod.txt"
        n=$(( $(wc -l < "$K_OUT/lsmod.txt") - 1 ))
        info "localmodconfig: $n modules are loaded now"
        run_logged kmake LSMOD="$K_OUT/lsmod.txt" localmodconfig || die "localmodconfig failed"
        for sym in "${KEEP_DEFAULT[@]}" "${KF_KEEP[@]}"; do
            [[ $(cfg_value "$sym" "$base") == m ]] && kcfg -m "$sym"
        done
    fi

    # Distribution kernels may name key files that this tree does not have
    kcfg --set-str SYSTEM_TRUSTED_KEYS "" --set-str SYSTEM_REVOCATION_KEYS "" \
         -d LOCALVERSION_AUTO

    if (( KF_NATIVE )); then
        if grep -q '^config X86_NATIVE_CPU' "$K_SRC/arch/x86/Kconfig.cpu" 2>/dev/null; then
            kcfg -e X86_NATIVE_CPU
        else
            info "this version has no X86_NATIVE_CPU (from 6.16): no CPU tuning"
        fi
    fi

    choose_release
    config_check
    ok "configuration ready: $K_OUT/.config (release $K_REL)"
}

# A release name that no installed kernel has: -kf, -kf2, ... Nothing is ever overwritten.
choose_release() {
    local n=1 lv
    while (( n < 100 )); do
        lv=$KF_SUFFIX; (( n > 1 )) && lv=$KF_SUFFIX$n
        kcfg --set-str LOCALVERSION "$lv"
        run_logged kmake olddefconfig || die "olddefconfig failed"
        # kernelrelease reads what the configuration generated: bring that up to date first
        kmake -s include/config/kernel.release >> "$LOGFILE" 2>&1 || die "cannot work out the kernel release"
        K_REL=$(kmake -s kernelrelease 2>/dev/null)
        [[ $K_REL =~ ^[0-9][0-9A-Za-z._+-]*$ ]] || die "no kernel release from the source ('$K_REL')"
        [[ $K_REL != "$CUR_REL" ]] || die "$K_REL is the running kernel"
        if (( DRY_RUN )); then return 0; fi
        priv_test_e "$MOD_ROOT/$K_REL" || priv_test_e "$BOOT_DIR/vmlinuz-$K_REL" || return 0
        (( n++ ))
    done
    die "no free release name"
}

# What must be in the kernel to boot and use this machine; a reduced configuration that lacks it
# is not installed.
config_check() {
    local cfg=$K_OUT/.config sym v
    local -A fs=([ext4]=EXT4_FS [ext3]=EXT4_FS [ext2]=EXT4_FS [btrfs]=BTRFS_FS [xfs]=XFS_FS [f2fs]=F2FS_FS)
    sym=${fs[${ROOT_FS-}]-}
    if [[ -n $sym ]]; then
        v=$(cfg_value "$sym" "$cfg")
        [[ -n $v ]] || die "the root file system ($ROOT_FS) is not in the configuration"
    fi
    if [[ $LUKS_ROOT == yes ]]; then
        [[ -n $(cfg_value DM_CRYPT "$cfg") ]] || die "the root is encrypted and DM_CRYPT is not in the configuration"
    fi
    if [[ -n $ESP && -z $(cfg_value VFAT_FS "$cfg") ]]; then
        die "the boot partition is FAT and VFAT_FS is not in the configuration"
    fi
    if (( KF_NATIVE )) && grep -q '^config X86_NATIVE_CPU' "$K_SRC/arch/x86/Kconfig.cpu" 2>/dev/null \
            && [[ $(cfg_value X86_NATIVE_CPU "$cfg") != y ]]; then
        warn "X86_NATIVE_CPU did not stay on (the compiler?): the kernel is not tuned to this CPU"
    fi
    if [[ $(cfg_value DEBUG_INFO_BTF "$K_OUT/.config.base") == y && $(cfg_value DEBUG_INFO_BTF "$cfg") != y ]]; then
        die "BTF is off now (pahole missing?): programs that use BPF would not work"
    fi
}
