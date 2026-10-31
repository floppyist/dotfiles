# shellcheck shell=bash
# kernelforge/lib/detect.sh  ·  what this machine is. detect_system sets the variables, runs
# nothing that changes the system.

EFI_VARS=/sys/firmware/efi/efivars

detect_system() {
    local l v

    [[ $(uname -m) == x86_64 ]] || die "only x86_64 is supported (this is $(uname -m))"
    CUR_REL=$(uname -r)
    CUR_VER=${CUR_REL%%[!0-9.]*}                       # 6.18.59_1 -> 6.18.59
    CUR_VER=${CUR_VER%.}
    [[ $CUR_VER =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || die "cannot read the kernel version from '$CUR_REL'"
    SERIES=${CUR_VER%.*}
    [[ $CUR_VER == *.*.* ]] || SERIES=$CUR_VER

    CPU_MODEL=$(sed -n 's/^model name[[:space:]]*:[[:space:]]*//p' /proc/cpuinfo | head -1)
    CPU_THREADS=$(nproc)
    DISTRO=Linux
    if [[ -r /etc/os-release ]]; then
        while IFS='=' read -r l v; do
            [[ $l == PRETTY_NAME ]] && { DISTRO=${v#\"}; DISTRO=${DISTRO%\"}; }
        done < /etc/os-release
    fi

    BOOT_DIR=$KF_SYSROOT/boot
    MOD_ROOT=$KF_SYSROOT/lib/modules

    ROOT_FS=$(findmnt -no FSTYPE / 2>/dev/null)
    ROOT_SRC=$(findmnt -no SOURCE / 2>/dev/null); ROOT_SRC=${ROOT_SRC%%\[*}
    LUKS_ROOT=no
    if [[ -b $ROOT_SRC ]] && lsblk -nso TYPE "$ROOT_SRC" 2>/dev/null | grep -qx crypt; then
        LUKS_ROOT=yes
    fi

    detect_boot

    INITRAMFS=none
    if command -v dracut >/dev/null; then INITRAMFS=dracut
    elif command -v mkinitcpio >/dev/null; then INITRAMFS=mkinitcpio
    elif command -v update-initramfs >/dev/null; then INITRAMFS=update-initramfs
    fi

    SECURE_BOOT=no
    for l in "$EFI_VARS"/SecureBoot-*; do
        # 4 bytes of attributes, then the value
        [[ -r $l ]] && [[ $(od -An -tu1 -j4 -N1 "$l" 2>/dev/null | tr -d ' ') == 1 ]] && SECURE_BOOT=yes
    done

    DKMS_MODULES=0
    command -v dkms >/dev/null && DKMS_MODULES=$(dkms status 2>/dev/null | grep -c .)
}

# The boot loader: systemd-boot tells the firmware its name (LoaderInfo), GRUB is a config file
detect_boot() {
    local d
    ESP=""
    for d in /boot/efi /efi /boot; do
        [[ $(findmnt -no FSTYPE "$KF_SYSROOT$d" 2>/dev/null) == vfat ]] && { ESP=$KF_SYSROOT$d; break; }
    done
    BOOTLOADER=unknown GRUB_CFG=""
    for d in "$EFI_VARS"/LoaderInfo-*; do
        [[ -r $d ]] && grep -aq 'systemd-boot' "$d" && BOOTLOADER=systemd-boot
    done
    if [[ $BOOTLOADER == systemd-boot && -z $ESP ]]; then BOOTLOADER=unknown; fi
    # /boot is often readable for root only: the config file is looked for at installation
    if [[ $BOOTLOADER == unknown ]] && { command -v grub-mkconfig >/dev/null || command -v update-grub >/dev/null; }; then
        { [[ -e $KF_SYSROOT/etc/default/grub ]] || [[ -e $BOOT_DIR/grub ]]; } && BOOTLOADER=grub
    fi
}

# test -e as root, without a password prompt when there is none to give
priv_test_e() {
    [[ -e $1 ]] && return 0
    [[ -r ${1%/*} ]] && return 1                       # readable and not there
    (( EUID == 0 )) || sudo -n true 2>/dev/null || return 1
    priv test -e "$1" 2>/dev/null
}

# The configuration of the running kernel -> $1. /proc/config.gz is the real one; /boot is
# readable for root only.
read_running_config() {
    if [[ -r /proc/config.gz ]] && gzip -dc /proc/config.gz > "$1" 2>/dev/null && [[ -s $1 ]]; then
        BASE_CONFIG=/proc/config.gz
    elif [[ -r $BOOT_DIR/config-$CUR_REL ]]; then
        cp -- "$BOOT_DIR/config-$CUR_REL" "$1"; BASE_CONFIG=$BOOT_DIR/config-$CUR_REL
    elif priv cat "$BOOT_DIR/config-$CUR_REL" > "$1" 2>/dev/null && [[ -s $1 ]]; then
        BASE_CONFIG=$BOOT_DIR/config-$CUR_REL
    else
        die "no configuration of the running kernel (no /proc/config.gz, no $BOOT_DIR/config-$CUR_REL)"
    fi
}

show_system() {
    step "This machine"
    info "CPU          $(clean "${CPU_MODEL:-?}") ($CPU_THREADS threads)"
    info "Distribution $(clean "$DISTRO")"
    info "Kernel now   $CUR_REL"
    info "Root         ${ROOT_SRC:-?} (${ROOT_FS:-?}), encrypted: $LUKS_ROOT"
    info "Boot loader  $BOOTLOADER${ESP:+, ESP $ESP}"
    info "Initramfs    $INITRAMFS"
    info "Secure Boot  $SECURE_BOOT"
}
