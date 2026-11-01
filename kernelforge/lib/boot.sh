# shellcheck shell=bash
# kernelforge/lib/boot.sh  ·  the installation, as root. The new kernel gets its own names
# (release ...-kf): modules, vmlinuz, initramfs, boot entry. Nothing of the running kernel is
# touched; if a step fails, what this run created is removed again (on_exit in common.sh).

# install FILE to DEST (root, atomic: written beside it, then renamed)
put_file() {
    local src=$1 dst=$2 mode=$3
    ROLLBACK+=("$dst" "$dst.new")
    priv install -m "$mode" -T -- "$src" "$dst.new" || die "cannot write $dst"
    priv mv -T -- "$dst.new" "$dst" || die "cannot write $dst"
}

# the kernel command line of the running system, without what the boot loader adds
clean_cmdline() {
    local w out=()
    for w in $(< /proc/cmdline); do
        case $w in BOOT_IMAGE=*|initrd=*) ;; *) out+=("$w") ;; esac
    done
    clean "${out[*]}"
}

install_preflight() {
    local need=$(( 300 * 1048576 )) p
    # nothing that exists is overwritten (and so nothing of it is removed again on failure)
    for p in "$MOD_ROOT/$K_REL" "$BOOT_DIR/vmlinuz-$K_REL" "$BOOT_DIR/initramfs-$K_REL.img" "$BOOT_DIR/initrd.img-$K_REL"; do
        priv_test_e "$p" && die "$p exists already"
    done
    (( $(free_bytes "$BOOT_DIR") >= need )) || die "less than 300 MB free in $BOOT_DIR"
    if [[ $BOOTLOADER == systemd-boot && $ESP != "$BOOT_DIR" ]]; then
        (( $(free_bytes "$ESP") >= need )) || die "less than 300 MB free in $ESP"
    fi
    [[ $INITRAMFS != none ]] || warn "no initramfs tool (dracut, mkinitcpio, initramfs-tools): the kernel may not boot"
    if [[ $BOOTLOADER == unknown ]]; then
        warn "boot loader not recognized: the files are installed, the entry is yours to add"
    fi
}

install_kernel() {
    local rel=$K_REL vmlinuz=$BOOT_DIR/vmlinuz-$K_REL initrd entry
    step "Installation (root)"
    install_preflight

    detail "modules"
    ROLLBACK+=("$MOD_ROOT/$rel")
    priv mkdir -p -- "$MOD_ROOT" || die "cannot create $MOD_ROOT"
    # new files belong to root, whatever owns the staging directory
    priv cp -a --no-preserve=ownership -- "$STAGE/lib/modules/$rel" "$MOD_ROOT/$rel" || die "copying the modules failed"
    run_logged priv depmod -a -b "${KF_SYSROOT:-/}" "$rel" || warn "depmod failed"
    ok "modules: $MOD_ROOT/$rel"

    detail "kernel image"
    put_file "$K_OUT/arch/x86/boot/bzImage" "$vmlinuz" 0644
    put_file "$K_OUT/System.map" "$BOOT_DIR/System.map-$rel" 0644
    put_file "$K_OUT/.config" "$BOOT_DIR/config-$rel" 0644
    ok "kernel: $vmlinuz"

    detail "initramfs"
    make_initramfs
    detail "boot entry"
    add_boot_entry

    ROLLBACK=()
    ok "kernel $rel installed"
    note "Kernel $rel is installed next to the running $CUR_REL. Choose it in the boot menu; the old one stays."
    (( DKMS_MODULES )) && note "DKMS modules (NVIDIA, ...) were not built for $rel: it has no build directory."
    return 0
}

make_initramfs() {
    local rel=$K_REL
    INITRD=""
    case $INITRAMFS in
        dracut)           INITRD=$BOOT_DIR/initramfs-$rel.img
                          ROLLBACK+=("$INITRD")
                          run_logged priv dracut --force --kver "$rel" "$INITRD" "$rel" || die "dracut failed" ;;
        mkinitcpio)       INITRD=$BOOT_DIR/initramfs-$rel.img
                          ROLLBACK+=("$INITRD")
                          run_logged priv mkinitcpio -k "$rel" -g "$INITRD" || die "mkinitcpio failed" ;;
        update-initramfs) INITRD=$BOOT_DIR/initrd.img-$rel
                          ROLLBACK+=("$INITRD")
                          run_logged priv update-initramfs -c -k "$rel" || die "update-initramfs failed" ;;
        *)                warn "no initramfs: skipped"; return 0 ;;
    esac
    priv test -s "$INITRD" || die "the initramfs was not written: $INITRD"
    ok "initramfs: $INITRD"
}

add_boot_entry() {
    local rel=$K_REL
    case $BOOTLOADER in
        grub)
            # grub-mkconfig finds every vmlinuz-* in /boot: the new kernel appears by itself
            (( KF_SET_DEFAULT )) && { grub_saved_default || warn "GRUB_DEFAULT is not 'saved': the new kernel will not be the default"; }
            GRUB_CFG=$BOOT_DIR/grub/grub.cfg
            priv_test_e "$BOOT_DIR/grub2/grub.cfg" && GRUB_CFG=$BOOT_DIR/grub2/grub.cfg
            if command -v grub-mkconfig >/dev/null; then
                run_logged priv grub-mkconfig -o "${GRUB_CFG#"$KF_SYSROOT"}" || die "grub-mkconfig failed"
            else
                run_logged priv update-grub || die "update-grub failed"
            fi
            priv grep -q -- "vmlinuz-$rel" "$GRUB_CFG" 2>/dev/null \
                || warn "$rel is not in $GRUB_CFG: add it by hand"
            ok "GRUB: $GRUB_CFG updated"
            if (( KF_SET_DEFAULT )); then
                if grub_set_default "$rel" "$GRUB_CFG"; then
                    ok "GRUB: $rel is the default entry"
                    note "Kernel $rel is the default in the GRUB menu. The old kernel is under Advanced options; to go back: grub-set-default with its entry, or choose it once in the menu."
                else
                    warn "could not make $rel the default entry: choose it in the GRUB menu (Advanced options)"
                fi
            else
                note "GRUB may make the new kernel the default (the newest version): the old one is under Advanced options."
            fi
            ;;
        systemd-boot)
            local dir=$ESP/loader/entries conf lin ini
            conf=$dir/kernelforge-$rel.conf
            if [[ $ESP == "$BOOT_DIR" ]]; then
                lin=/vmlinuz-$rel ini=${INITRD:+/${INITRD##*/}}
            else
                # the boot loader reads the ESP only: copy the kernel there
                priv mkdir -p -- "$ESP/kernelforge" || die "cannot create $ESP/kernelforge"
                put_file "$BOOT_DIR/vmlinuz-$rel" "$ESP/kernelforge/vmlinuz-$rel" 0644
                lin=/kernelforge/vmlinuz-$rel ini=""
                if [[ -n $INITRD ]]; then
                    put_file "$INITRD" "$ESP/kernelforge/${INITRD##*/}" 0644
                    ini=/kernelforge/${INITRD##*/}
                fi
            fi
            priv mkdir -p -- "$dir" || die "cannot create $dir"
            mktmp; local tmp=$MKTMP/entry
            printf 'title   Linux %s (kernelforge)\nversion %s\nlinux   %s\n%soptions %s\n' \
                "$rel" "$rel" "$lin" "${ini:+initrd  $ini$'\n'}" "$(clean_cmdline)" > "$tmp" || die "cannot write the entry"
            put_file "$tmp" "$conf" 0644
            ok "systemd-boot: $conf"
            if (( KF_SET_DEFAULT )) && [[ -z $KF_SYSROOT ]] && command -v bootctl >/dev/null; then
                if run_logged priv bootctl set-default "${conf##*/}"; then
                    ok "systemd-boot: $rel is the default entry"
                else
                    warn "could not make $rel the default entry: choose it in the boot menu"
                fi
            fi
            ;;
        *)
            note "Add boot entry by hand: kernel $BOOT_DIR/vmlinuz-$rel${INITRD:+, initrd $INITRD}, command line like /proc/cmdline."
            ;;
    esac
}

# GRUB only remembers a default entry with GRUB_DEFAULT=saved (grub-set-default writes it to grubenv)
grub_saved_default() {
    local f=$KF_SYSROOT/etc/default/grub tmp
    [[ -r $f ]] || return 1
    grep -Eq '^[[:space:]]*GRUB_DEFAULT=("?)saved\1[[:space:]]*$' "$f" && return 0
    mktmp; tmp=$MKTMP/grub-default
    awk 'BEGIN { d = 0 }
         /^[ \t]*GRUB_DEFAULT=/ { if (!d) print "GRUB_DEFAULT=saved"; d = 1; next }
         { print }
         END { if (!d) print "GRUB_DEFAULT=saved" }' "$f" > "$tmp" || return 1
    priv cp -n -- "$f" "$f.kernelforge-bak" 2>/dev/null
    priv install -m 0644 -T -- "$tmp" "$f" || return 1
    ok "/etc/default/grub: GRUB_DEFAULT=saved (the old file: $f.kernelforge-bak)"
}

# The menu entry of kernel $1 in the generated config $2 -> grub-set-default. The entry sits in the
# submenu "Advanced options" (gnulinux-advanced-UUID>gnulinux-RELEASE-advanced-UUID) unless the
# submenu is switched off.
grub_set_default() {
    local rel=$1 cfg=$2 text line sub="" id="" rest
    text=$(priv cat -- "$cfg" 2>/dev/null) || return 1
    while IFS= read -r line; do
        if [[ $line == submenu\ * && $line == *"'gnulinux-advanced-"* ]]; then
            rest=${line#*"'gnulinux-advanced-"}
            sub=gnulinux-advanced-${rest%%"'"*}
        elif [[ $line == *"menuentry "* && $line == *"'gnulinux-$rel-advanced-"* ]]; then
            rest=${line#*"'gnulinux-$rel-advanced-"}
            id=gnulinux-$rel-advanced-${rest%%"'"*}
            break
        fi
    done <<< "$text"
    [[ -n $id ]] || return 1
    run_logged priv grub-set-default "${sub:+$sub>}$id"
}
