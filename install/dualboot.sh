# shellcheck shell=bash
# install/dualboot.sh  ·  a second system next to this one. The installer
#   1. makes a partition from UNALLOCATED space (nothing existing is shrunk or deleted; the table
#      is saved first),
#   2. puts the installer of the other system on it (ISO downloaded and checked against the
#      published SHA-256; Windows: your ISO, copied onto a FAT32 partition),
#   3. adds a GRUB entry that boots it. The rest of the free space stays free: the installer of the
#      new system offers it.
# The system itself is then installed by its own installer (reboot, choose the entry).
# ./install.sh dualboot-clean removes the entry and the partition again.

OSES=(arch debian ubuntu fedora alpine windows)
declare -A OS_TITLE OS_DESC OS_NEED OS_MB OS_EXP OS_WIN

OS_TITLE[arch]="Arch Linux"
OS_DESC[arch]="The current ISO of archlinux.org (about 1.4 GB). Its installer (archinstall or the manual way) installs into the free space."
OS_NEED[arch]=20 OS_MB[arch]=1400

OS_TITLE[debian]="Debian"
OS_DESC[debian]="The current stable netinst ISO of debian.org (about 0.8 GB). The installer needs a network connection and offers the free space."
OS_NEED[debian]=20 OS_MB[debian]=800

OS_TITLE[ubuntu]="Ubuntu (LTS)"
OS_DESC[ubuntu]="The newest Ubuntu 24.04 LTS Desktop ISO of ubuntu.com (about 6 GB). Boots the live system; \"Install Ubuntu\" uses the free space."
OS_NEED[ubuntu]=30 OS_MB[ubuntu]=6200

OS_TITLE[fedora]="Fedora Workstation"
OS_DESC[fedora]="The current Fedora Workstation Live ISO of fedoraproject.org (about 2.9 GB). Boot line written for it, not tested on hardware."
OS_NEED[fedora]=30 OS_MB[fedora]=2900 OS_EXP[fedora]=1

OS_TITLE[alpine]="Alpine Linux"
OS_DESC[alpine]="The current Alpine standard ISO of alpinelinux.org (about 0.4 GB), copied onto the partition; setup-alpine installs into the free space. Boot line written for it, not tested on hardware."
OS_NEED[alpine]=8 OS_MB[alpine]=400 OS_EXP[alpine]=1

OS_TITLE[windows]="Windows 10 / 11"
OS_DESC[windows]="Your Windows ISO (Microsoft offers no stable download link: get it from microsoft.com/software-download and put it in ~/Downloads). Copied onto a FAT32 partition, install.wim split for FAT32; Windows Setup then installs into the free space. UEFI only."
OS_NEED[windows]=64 OS_MB[windows]=6500 OS_WIN[windows]=1

ISO_LABEL=DOTFILES-ISO         # partition label of the installer partition (Linux)
WIN_LABEL=WININSTALL           # the same for the Windows setup (FAT32: 11 characters at most)
GRUB_ISO_ENTRY=$SYSROOT/etc/grub.d/45_dotfiles_iso
CURL_SAFE=(curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 20)

DUAL_TARGET=""       # one of OSES; empty = only detect
DUAL_DISK=""         # /dev/...
WIN_ISO=""           # path of the Windows ISO

# ── Disks ─────────────────────────────────────────────────────────────────────────

# Internal disks and the space no partition uses (an estimate without root: size minus the
# partitions) -> DISKS, DISK_FREE (bytes), DISK_DESC
detect_disks() {
    local line name size type rm ro model tran psum t s
    DISKS=() DISK_FREE=() DISK_DESC=() DISK_TRAN=()
    command -v lsblk >/dev/null || return 0
    while IFS= read -r line; do
        [[ $line =~ NAME=\"([^\"]*)\" ]] && name=${BASH_REMATCH[1]} || continue
        [[ $line =~ SIZE=\"([0-9]*)\" ]] && size=${BASH_REMATCH[1]} || continue
        [[ $line =~ TYPE=\"([^\"]*)\" ]] && type=${BASH_REMATCH[1]} || continue
        [[ $line =~ RM=\"([01])\" ]] && rm=${BASH_REMATCH[1]} || rm=0
        [[ $line =~ RO=\"([01])\" ]] && ro=${BASH_REMATCH[1]} || ro=0
        model=""; [[ $line =~ MODEL=\"([^\"]*)\" ]] && model=${BASH_REMATCH[1]}
        tran=""; [[ $line =~ TRAN=\"([^\"]*)\" ]] && tran=${BASH_REMATCH[1]}
        [[ $type == disk && $rm == 0 && $ro == 0 && $name == /dev/* && $size -gt 0 ]] || continue
        psum=0
        while read -r s t; do
            [[ $t == part && $s =~ ^[0-9]+$ ]] && (( psum += s ))
        done < <(lsblk -bnrpo SIZE,TYPE "$name" 2>/dev/null)
        # 2 MiB at the start, the GPT copy at the end
        s=$(( size - psum - 3 * 1048576 ))
        (( s < 0 )) && s=0
        DISKS+=("$name") DISK_FREE+=("$s")
        human_size "$size"
        DISK_TRAN+=("${tran//[^a-z0-9]/}")
        DISK_DESC+=("${model//[[:cntrl:]]/ } ($_HS${tran:+, ${tran//[^a-z0-9]/}})")
    done < <(lsblk -bdnPp -o NAME,SIZE,TYPE,RM,RO,MODEL,TRAN 2>/dev/null)
}

# Disks with at least $1 GiB free -> DISK_OK (indices into DISKS)
disks_with_room() {
    local i need=$(( $1 * 1073741824 ))
    DISK_OK=()
    for i in "${!DISKS[@]}"; do (( DISK_FREE[i] >= need )) && DISK_OK+=("$i"); done
}

# The largest unpartitioned stretch of disk $1 (root) -> GAP_START GAP_SECTORS SECTOR (512-byte
# units of the disk's sector size)
largest_gap() {
    local disk=$1 a b c best=0
    GAP_START=0 GAP_SECTORS=0
    SECTOR=$(as_root blockdev --getss "$disk" 2>/dev/null)
    [[ $SECTOR =~ ^[0-9]+$ ]] || SECTOR=512
    while read -r a b c _; do
        [[ $a =~ ^[0-9]+$ && $b =~ ^[0-9]+$ && $c =~ ^[0-9]+$ ]] || continue
        (( c > best )) && { best=$c; GAP_START=$a GAP_SECTORS=$c; }
    done < <(as_root sfdisk --list-free "$disk" 2>/dev/null)
    (( GAP_SECTORS > 0 ))
}

# The partition with label $1 -> PART (empty: none)
find_part() {
    local n l
    PART=""
    while read -r n l; do
        [[ $l == "$1" ]] && { PART=$n; return 0; }
    done < <(lsblk -nrpo NAME,LABEL 2>/dev/null)
    return 1
}

# Makes a partition of $2 bytes at the END of the largest free stretch of disk $1, formatted as $3
# (ext4 or vfat) with label $4 -> PART. The partition table is saved first.
make_partition() {
    local disk=$1 bytes=$2 fs=$3 label=$4 ptt type ss sectors start end before after n dump i
    # GRUB must see the disk (BIOS/EFI drive): a disk it cannot address ("cannot find a GRUB drive")
    # could not boot the installer entry; checked before anything is written
    if command -v grub-probe >/dev/null && ! as_root grub-probe -t drive -d "$disk" >/dev/null 2>&1; then
        warn "GRUB cannot address $disk (grub-probe: no drive; often a USB disk or one the firmware does not list): choose another disk"
        return 1
    fi
    ptt=$(lsblk -dno PTTYPE "$disk" 2>/dev/null)
    case $ptt in gpt|dos) ;; *) warn "$disk has no GPT or MBR partition table ($ptt)"; return 1 ;; esac
    largest_gap "$disk" || { warn "no unpartitioned space on $disk"; return 1; }
    ss=$SECTOR
    sectors=$(( (bytes + 1048575) / 1048576 * 1048576 / ss ))
    end=$(( GAP_START + GAP_SECTORS - 1 ))
    start=$(( (end + 1 - sectors) / 2048 * 2048 ))
    if (( start < GAP_START )); then
        warn "the largest free stretch of $disk is too small for $(( bytes / 1048576 )) MB"
        return 1
    fi
    if [[ $ptt == dos ]]; then
        n=$(lsblk -nrpo TYPE,NAME "$disk" 2>/dev/null | grep -c '^part')
        (( n >= 4 )) && { warn "$disk has 4 primary partitions: no room for another"; return 1; }
    fi
    # the old table, to put back with: sfdisk DISK < FILE
    dump=$STATE_DIR/partition-table-${disk##*/}-$STAMP.sfdisk
    as_root sfdisk --dump "$disk" > "$dump" 2>/dev/null && say "partition table saved: $dump (restore: sudo sfdisk $disk < $dump)"
    note "Partition table of $disk saved to ${dump/#$HOME/\~} (sudo sfdisk $disk < FILE puts it back)."
    case $fs$ptt in
        ext4*)    type=L ;;
        vfatgpt)  type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 ;;
        vfatdos)  type=c ;;
    esac
    before=$(lsblk -nrpo NAME "$disk" 2>/dev/null)
    detail "partitioning $disk"
    printf 'start=%d, size=%d, type=%s\n' "$start" "$sectors" "$type" | as_root sfdisk --append -q "$disk" >/dev/null || {
        warn "sfdisk failed on $disk"; return 1; }
    as_root udevadm settle 2>/dev/null
    PART=""
    for (( i = 0; i < 15; i++ )); do
        after=$(lsblk -nrpo NAME "$disk" 2>/dev/null)
        PART=$(comm -13 <(sort <<< "$before") <(sort <<< "$after") | head -1)
        [[ -b $PART ]] && break
        PART=""; sleep 1
    done
    [[ -n $PART ]] || { warn "the new partition did not show up (sudo partprobe $disk)"; return 1; }
    say "partition $PART: $(( sectors * ss / 1048576 )) MB"
    detail "formatting $PART"
    case $fs in
        ext4) as_root mkfs.ext4 -q -F -L "$label" "$PART" || return 1 ;;
        vfat) as_root mkfs.vfat -F 32 -n "$label" "$PART" >/dev/null || return 1 ;;
    esac
    as_root udevadm settle 2>/dev/null
    return 0
}

# ── ISO sources ───────────────────────────────────────────────────────────────────

# os_resolve ID -> ISO_URL ISO_SHA (the file name on the partition is ID.iso). The checksums
# come from the same https server as the file.
os_resolve() {
    local base sums line n h
    ISO_URL="" ISO_SHA=""
    case $1 in
        arch)
            base=https://geo.mirror.pkgbuild.com/iso/latest
            sums=$("${CURL_SAFE[@]}" "$base/sha256sums.txt") || return 1
            ISO_SHA=$(awk '$2 == "archlinux-x86_64.iso" {print $1; exit}' <<< "$sums")
            ISO_URL=$base/archlinux-x86_64.iso ;;
        debian)
            base=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
            sums=$("${CURL_SAFE[@]}" "$base/SHA256SUMS") || return 1
            line=$(grep -E '^[0-9a-f]{64}  debian-[0-9][0-9.]*-amd64-netinst\.iso$' <<< "$sums" | head -1)
            ISO_SHA=${line%% *}; n=${line##* }
            ISO_URL=$base/$n ;;
        ubuntu)
            base=https://releases.ubuntu.com/noble
            sums=$("${CURL_SAFE[@]}" "$base/SHA256SUMS") || return 1
            line=$(grep -E '^[0-9a-f]{64} \*ubuntu-[0-9][0-9.]*-desktop-amd64\.iso$' <<< "$sums" | sort -t'*' -k2 -V | tail -1)
            ISO_SHA=${line%% *}; n=${line##*\*}
            ISO_URL=$base/$n ;;
        fedora)
            base=https://dl.fedoraproject.org/pub/fedora/linux/releases
            n=$("${CURL_SAFE[@]}" "$base/" | grep -o 'href="[0-9][0-9]*/"' | tr -dc '0-9\n' | sort -n | tail -1)
            [[ $n =~ ^[0-9]+$ ]] || return 1
            base=$base/$n/Workstation/x86_64/iso
            h=$("${CURL_SAFE[@]}" "$base/" | grep -o 'Fedora-Workstation-Live-[0-9][0-9.-]*\.x86_64\.iso' | head -1)
            [[ -n $h ]] || return 1
            sums=$("${CURL_SAFE[@]}" "$base/$(sed 's/Workstation-Live-\([0-9][0-9]*\)-\([0-9.]*\)\.x86_64\.iso/Workstation-\1-\2-x86_64-CHECKSUM/' <<< "$h")") || return 1
            ISO_SHA=$(sed -n "s/^SHA256 ($h) = \([0-9a-f]\{64\}\)\$/\1/p" <<< "$sums")
            ISO_URL=$base/$h ;;
        alpine)
            base=https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64
            sums=$("${CURL_SAFE[@]}" "$base/latest-releases.yaml") || return 1
            line=$(awk '/flavor: alpine-standard$/ {f=1} f && /^  file:/ {n=$2} f && /^  sha256:/ {print $2, n; exit}' <<< "$sums")
            ISO_SHA=${line%% *}; n=${line##* }
            ISO_URL=$base/$n ;;
        *) return 1 ;;
    esac
    [[ $ISO_SHA =~ ^[0-9a-f]{64}$ && $ISO_URL == https://*.iso ]]
}

# Size of the file at URL $1 in bytes -> ISO_BYTES (0: unknown)
url_size() {
    ISO_BYTES=$("${CURL_SAFE[@]}" -sI -L "$1" 2>/dev/null | tr -d '\r' | awk 'tolower($1) == "content-length:" {n = $2} END {print n + 0}')
    [[ $ISO_BYTES =~ ^[0-9]+$ ]] || ISO_BYTES=0
}

# Downloads $1 to $2 (root, resumes), with @@progress. $3: expected size (0: unknown)
download_to() {
    local url=$1 dst=$2 total=${3:-0} pid size
    detail "downloading ${url##*/}"
    as_root curl -fL --proto '=https' --tlsv1.2 --retry 5 --retry-delay 5 --connect-timeout 20 -C - -sS -o "$dst" "$url" &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if (( total > 0 )); then
            size=$(stat -c %s "$dst" 2>/dev/null || echo 0)
            progress "$size" "$total"
            human_size "$size"; detail "downloading ${url##*/}: $_HS"
        fi
        sleep 2
    done
    wait "$pid"
}

# ── GRUB entry ────────────────────────────────────────────────────────────────────

# Installs /etc/grub.d/45_dotfiles_iso with the entry text from stdin
grub_entry_install() {
    local tmp
    tmp=$(mktemp) || return 1
    { printf '#!/bin/sh\n# dotfiles install.sh: boots the installer of a second system from its partition\n'
      printf 'exec tail -n +4 "$0"\n'
      cat; } > "$tmp"
    as_root install -m755 -T -- "$tmp" "$GRUB_ISO_ENTRY"; local rc=$?
    rm -f "$tmp"
    return "$rc"
}

# ── Plan and run ──────────────────────────────────────────────────────────────────

othersys_gib() {
    # partition (ISO and some room) + what the new system needs, in GiB, rounded up
    OS_TOTAL=$(( (OS_MB[$1] + 1024 + 1023) / 1024 + OS_NEED[$1] ))
}

plan_othersys() {
    local id=$DUAL_TARGET
    PLAN=()
    [[ -n $id ]] || return 1
    othersys_gib "$id"
    PLAN+=("!changes the partition table of ${DUAL_DISK:-a disk}: a partition from unallocated space, the old table is saved")
    PLAN+=("${OS_TITLE[$id]}: download about $(( OS_MB[$id] / 100 / 10 )).$(( OS_MB[$id] / 100 % 10 )) GB, checked against the published SHA-256")
    [[ $id == windows ]] && PLAN[1]="Windows: ${WIN_ISO:+${WIN_ISO##*/}, }copied onto a FAT32 partition, install.wim split for it"
    PLAN+=("a GRUB entry \"Install ${OS_TITLE[$id]}\" boots the installer from that partition")
    PLAN+=("the free space after that ($OS_TOTAL GB needed in total) stays free for the installer of ${OS_TITLE[$id]}")
    [[ $BOOTLOADER == grub ]] || PLAN+=("!needs GRUB: the boot loader is $BOOTLOADER")
    (( ${OS_EXP[$id]:-0} )) && PLAN+=("!boot line for ${OS_TITLE[$id]} is not tested on hardware")
    return 0
}

run_othersys() {
    local id=$DUAL_TARGET need total bytes mnt label fs src="" iso_name=$DUAL_TARGET.iso entry
    [[ -n $id ]] || { say "no second system chosen"; return 0; }
    detect_boot
    [[ $BOOTLOADER == grub ]] || { warn "needs GRUB (boot loader: $BOOTLOADER)"; return 1; }
    if (( ${OS_WIN[$id]:-0} )); then
        (( EFI )) || { warn "the Windows setup is prepared for UEFI only; this machine boots in BIOS mode"; return 1; }
        [[ -r $WIN_ISO ]] || { warn "Windows ISO not found: ${WIN_ISO:-none given}"; return 1; }
        command -v wimlib-imagex >/dev/null || { warn "wimlib is missing (package wimlib)"; return 1; }
        label=$WIN_LABEL fs=vfat
        bytes=$(stat -c %s "$WIN_ISO") || return 1
    else
        label=$ISO_LABEL fs=ext4
        detail "asking the server"
        os_resolve "$id" || { warn "${OS_TITLE[$id]}: could not read the download and checksum from the server"; return 1; }
        url_size "$ISO_URL"
        say "${OS_TITLE[$id]}: $ISO_URL"
        bytes=$ISO_BYTES
        (( bytes > 0 )) || bytes=$(( OS_MB[$id] * 1048576 ))
    fi
    command -v sfdisk >/dev/null || { warn "sfdisk is missing (util-linux)"; return 1; }
    othersys_gib "$id"; total=$OS_TOTAL need=${OS_NEED[$id]}

    # a partition of an earlier run (the download resumes)
    if find_part "$label"; then
        say "the installer partition $PART exists already: reusing it"
    else
        [[ -b $DUAL_DISK ]] || { warn "disk not found: ${DUAL_DISK:-none chosen}"; return 1; }
        # partition: the ISO and room to work, at the end of the free space; the rest stays free
        make_partition "$DUAL_DISK" $(( bytes + 1073741824 )) "$fs" "$label" || return 1
        # the new system needs room besides it
        largest_gap "$DUAL_DISK" 2>/dev/null
        if (( GAP_SECTORS * SECTOR < need * 1073741824 )); then
            warn "only $(( GAP_SECTORS * SECTOR / 1073741824 )) GB stay free for ${OS_TITLE[$id]} (it needs about $need GB): shrink a partition, or remove this one with ./install.sh dualboot-clean"
        fi
    fi
    mnt=$(mktemp -d) || return 1
    # shellcheck disable=SC2064
    trap "as_root umount '$mnt' 2>/dev/null; rmdir '$mnt' 2>/dev/null" EXIT
    as_root mount "$PART" "$mnt" || { warn "cannot mount $PART"; return 1; }

    if (( ${OS_WIN[$id]:-0} )); then
        prepare_windows "$mnt" || return 1
        entry=$(cat <<EOF
menuentry "Install Windows (setup from the disk)" --class windows --id dotfiles-windows {
    insmod part_gpt
    insmod part_msdos
    insmod fat
    insmod chain
    insmod search_label
    search --no-floppy --label --set=root $WIN_LABEL
    chainloader /efi/boot/bootx64.efi
}
EOF
)
    else
        if [[ -f $mnt/$iso_name ]] && sha_ok "$mnt/$iso_name"; then
            say "$iso_name is there and its checksum is right"
        else
            download_to "$ISO_URL" "$mnt/$iso_name" "${ISO_BYTES:-0}" || { warn "download failed (run again to resume)"; return 1; }
            sha_ok "$mnt/$iso_name" || { warn "SHA-256 of $iso_name is wrong: deleted, run again"; as_root rm -f "$mnt/$iso_name"; return 1; }
        fi
        entry=$(linux_entry "$id" "$mnt/$iso_name" "$mnt") || return 1
    fi
    as_root sync
    as_root umount "$mnt" && rmdir "$mnt"
    trap - EXIT

    grub_entry_install <<< "$entry" || return 1
    say "GRUB entry: $GRUB_ISO_ENTRY"
    grub_regen || return 1
    note "${OS_TITLE[$id]}: restart and choose \"Install ${OS_TITLE[$id]%% *}...\" in the GRUB menu. Its installer offers the free space on the disk; leave the installer partition ($label) as it is until the new system is installed."
    note "${OS_TITLE[$id]}: when it is installed run ./install.sh dualboot-clean (removes the menu entry and the installer partition), then ./install.sh modules dualboot (puts the new system in the menu)."
    (( ${OS_WIN[$id]:-0} )) && note "Windows: its setup puts \"Windows Boot Manager\" first in the firmware boot order. GRUB is still there: choose Void in the firmware boot menu once and run  sudo efibootmgr -o  with the Void entry first, or pick it with the boot menu key."
    need_reboot
    return 0
}

# SHA-256 of file $1 is ISO_SHA (root: the partition is root's)
sha_ok() {
    local sum
    detail "checking the SHA-256 of ${1##*/}"
    sum=$(as_root sha256sum "$1" 2>/dev/null) || return 1
    [[ ${sum%% *} == "$ISO_SHA" ]]
}

# GRUB entry text of Linux system $1 (ISO $2 on mount $3) -> stdout
linux_entry() {
    local id=$1 iso=$2 mnt=$3 label uuid
    local head='    insmod part_gpt
    insmod part_msdos
    insmod ext2
    insmod loopback
    insmod iso9660
    insmod search_label'
    case $id in
        arch|debian|ubuntu)
            # these ISOs bring a loopback.cfg for exactly this
            cat <<EOF
menuentry "Install ${OS_TITLE[$id]} (installer from the disk)" --class $id --id dotfiles-$id {
$head
    search --no-floppy --label --set=isodev $ISO_LABEL
    set iso_path="/$id.iso"
    export iso_path
    loopback loop (\$isodev)\$iso_path
    set root=(loop)
    configfile /boot/grub/loopback.cfg
}
EOF
            ;;
        fedora)
            label=$(as_root blkid -s LABEL -o value "$iso" 2>/dev/null)
            [[ $label =~ ^[A-Za-z0-9._-]+$ ]] || { warn "cannot read the volume label of the ISO ($label)"; return 1; }
            cat <<EOF
menuentry "Install Fedora (installer from the disk)" --class fedora --id dotfiles-fedora {
$head
    search --no-floppy --label --set=isodev $ISO_LABEL
    loopback loop (\$isodev)/fedora.iso
    linux (loop)/images/pxeboot/vmlinuz root=live:CDLABEL=$label iso-scan/filename=/fedora.iso rd.live.image quiet
    initrd (loop)/images/pxeboot/initrd.img
}
EOF
            ;;
        alpine)
            # the ISO is unpacked: Alpine's initramfs looks for the files, not for an ISO
            as_root mkdir -p "$mnt/alpine" || return 1
            detail "unpacking the Alpine ISO"
            local tmp; tmp=$(mktemp -d) || return 1
            as_root mount -o loop,ro "$iso" "$tmp" || { rmdir "$tmp"; warn "cannot mount the ISO"; return 1; }
            as_root cp -r "$tmp"/. "$mnt/alpine/" ; local rc=$?
            as_root umount "$tmp"; rmdir "$tmp"
            (( rc == 0 )) || { warn "copying the Alpine ISO failed"; return 1; }
            uuid=$(as_root blkid -s UUID -o value "$PART" 2>/dev/null)
            [[ $uuid =~ ^[A-Fa-f0-9-]+$ ]] || { warn "no UUID for $PART"; return 1; }
            cat <<EOF
menuentry "Install Alpine (installer from the disk)" --class alpine --id dotfiles-alpine {
    insmod part_gpt
    insmod part_msdos
    insmod ext2
    insmod search_label
    search --no-floppy --label --set=root $ISO_LABEL
    linux /alpine/boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage,nvme,ext4 alpine_dev=UUID=$uuid quiet
    initrd /alpine/boot/initramfs-lts
}
EOF
            ;;
    esac
}

# The Windows ISO $WIN_ISO onto the FAT32 partition mounted at $1
prepare_windows() {
    local dst=$1 src wim size
    src=$(mktemp -d) || return 1
    detail "mounting the Windows ISO"
    as_root mount -o loop,ro "$WIN_ISO" "$src" || { rmdir "$src"; warn "cannot mount $WIN_ISO (is it an ISO?)"; return 1; }
    wim=$(find "$src" -maxdepth 2 -ipath '*/sources/install.wim' | head -1)
    [[ -z $wim ]] && wim=$(find "$src" -maxdepth 2 -ipath '*/sources/install.esd' | head -1)
    if [[ -z $wim ]] || ! find "$src" -maxdepth 3 -ipath '*/efi/boot/bootx64.efi' | grep -q .; then
        as_root umount "$src"; rmdir "$src"
        warn "this is not a Windows 64-bit UEFI installation ISO (sources/install.wim or efi/boot/bootx64.efi missing)"
        return 1
    fi
    size=$(stat -c %s "$wim")
    detail "copying the files"
    ( cd "$src" && as_root tar cf - --exclude="${wim#"$src"/}" . ) | ( cd "$dst" && as_root tar xf - --no-same-owner --no-same-permissions )
    if (( ${PIPESTATUS[0]} || ${PIPESTATUS[1]} )); then
        as_root umount "$src"; rmdir "$src"; warn "copying the Windows files failed"; return 1
    fi
    as_root mkdir -p "$dst/sources"
    if (( size >= 4294967295 )) && [[ $wim == *.wim ]]; then
        detail "splitting install.wim for FAT32"
        as_root wimlib-imagex split "$wim" "$dst/sources/install.swm" 3800 >/dev/null || { as_root umount "$src"; rmdir "$src"; warn "wimlib-imagex split failed"; return 1; }
    else
        detail "copying ${wim##*/}"
        as_root cp "$wim" "$dst/sources/${wim##*/}" || { as_root umount "$src"; rmdir "$src"; return 1; }
    fi
    as_root umount "$src"; rmdir "$src"
    say "Windows setup files are on the partition"
}

# ── Remove again (./install.sh dualboot-clean) ────────────────────────────────────

dualboot_clean() {
    local p disk num answer found=0
    [[ -e $GRUB_ISO_ENTRY ]] && found=1
    for p in "$ISO_LABEL" "$WIN_LABEL"; do find_part "$p" && found=1; done
    (( found )) || { echo "Nothing to remove: no installer entry, no installer partition."; return 0; }
    echo "This removes the GRUB entry of the second system's installer and the installer partition"
    echo "(label $ISO_LABEL or $WIN_LABEL, with the downloaded ISO). The new system and everything else stay."
    read -rp "Remove? [y/N] " answer
    [[ $answer == [yYjJ]* ]] || { echo "Nothing changed."; return 0; }
    sudo -v || return 1
    [[ -e $GRUB_ISO_ENTRY ]] && sudo rm -f "$GRUB_ISO_ENTRY" && echo "removed $GRUB_ISO_ENTRY"
    for p in "$ISO_LABEL" "$WIN_LABEL"; do
        find_part "$p" || continue
        sudo umount "$PART" 2>/dev/null
        disk=$(lsblk -no PKNAME "$PART" 2>/dev/null | head -1); disk=/dev/$disk
        num=$(cat "/sys/class/block/${PART##*/}/partition" 2>/dev/null)
        if [[ -b $disk && $num =~ ^[0-9]+$ ]]; then
            sudo sfdisk --delete "$disk" "$num" && echo "deleted $PART"
            sudo partprobe "$disk" 2>/dev/null
        fi
    done
    if command -v grub-mkconfig >/dev/null; then
        local cfg=/boot/grub/grub.cfg
        sudo test -e /boot/grub2/grub.cfg && cfg=/boot/grub2/grub.cfg
        sudo grub-mkconfig -o "$cfg" 2>&1 | grep -i 'found\|done' 
    fi
    sudo -k
}
