# shellcheck shell=bash
# install/dualboot.sh  ·  a second system next to this one. The installer
#   1. makes a partition from UNALLOCATED space (nothing existing is shrunk or deleted; the table
#      is saved first),
#   2. puts the installer of the other system on it (ISO downloaded, the distribution's signature
#      checked against its pinned key; Windows: your ISO, copied onto a FAT32 partition),
#   3. adds a GRUB entry that boots it. The rest of the free space stays free: the installer of the
#      new system offers it.
# The system itself is then installed by its own installer (reboot, choose the entry).
# ./install.sh dualboot-clean removes the entry and the partition again.
#
# The partition is ours only by the record in $DUAL_STATE (its PARTUUID and file system UUID),
# never by its label: a USB stick labelled the same must never be written to or deleted. GRUB
# finds it by the file system UUID for the same reason.

OSES=(arch debian ubuntu fedora alpine windows)
declare -A OS_TITLE OS_DESC OS_NEED OS_MB OS_EXP OS_WIN

OS_TITLE[arch]="Arch Linux"
OS_DESC[arch]="The current ISO of archlinux.org (about 1.4 GB). Its installer (archinstall or the manual way) installs into the free space."
OS_NEED[arch]=20 OS_MB[arch]=1400

OS_TITLE[debian]="Debian"
OS_DESC[debian]="The current stable netinst ISO of debian.org (about 0.8 GB). The installer needs a network connection and offers the free space."
OS_NEED[debian]=20 OS_MB[debian]=800

OS_TITLE[ubuntu]="Ubuntu (LTS)"
OS_DESC[ubuntu]="The Desktop ISO of the newest Ubuntu LTS from ubuntu.com (about 6 GB). Boots the live system; \"Install Ubuntu\" uses the free space."
OS_NEED[ubuntu]=30 OS_MB[ubuntu]=6200

OS_TITLE[fedora]="Fedora Workstation"
OS_DESC[fedora]="The current Fedora Workstation Live ISO of fedoraproject.org (about 2.9 GB). Boot line written for it, not tested on hardware."
OS_NEED[fedora]=30 OS_MB[fedora]=2900 OS_EXP[fedora]=1

OS_TITLE[alpine]="Alpine Linux"
OS_DESC[alpine]="The current Alpine standard ISO of alpinelinux.org (about 0.4 GB), unpacked onto the partition like a boot stick; setup-alpine installs into the free space. Boot line written for it, not tested on hardware."
OS_NEED[alpine]=8 OS_MB[alpine]=400 OS_EXP[alpine]=1

OS_TITLE[windows]="Windows 10 / 11"
OS_DESC[windows]="Your Windows ISO (Microsoft offers no stable download link: get it from microsoft.com/software-download and put it in ~/Downloads). Copied onto a FAT32 partition, install.wim split for FAT32; Windows Setup then installs into the free space. UEFI only."
OS_NEED[windows]=64 OS_MB[windows]=6500 OS_WIN[windows]=1

ISO_LABEL=DOTFILES-ISO         # file system label of the installer partition (Linux; only a hint)
WIN_LABEL=WININSTALL           # the same for the Windows setup (FAT32: 11 characters at most)
GRUB_ISO_ENTRY=$SYSROOT/etc/grub.d/45_dotfiles_iso
DUAL_STATE=$STATE_DIR/dualboot.state
CURL_SAFE=(curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --connect-timeout 20)

DUAL_TARGET=""       # one of OSES; empty = only detect
DUAL_DISK=""         # /dev/...
WIN_ISO=""           # path of the Windows ISO

# ── Disks ─────────────────────────────────────────────────────────────────────────

# Internal disks and the space no partition uses (an estimate without root: size minus the
# partitions) -> DISKS, DISK_FREE (bytes), DISK_DESC. USB disks are left out: the firmware and
# GRUB often cannot boot from them, and an installer stick must never be chosen. So are devices
# without a GPT or MBR partition table (zram swap, empty disks): make_partition needs one.
detect_disks() {
    local line name size type rm ro model tran pt psum t s
    DISKS=() DISK_FREE=() DISK_DESC=()
    command -v lsblk >/dev/null || return 0
    while IFS= read -r line; do
        [[ $line =~ NAME=\"([^\"]*)\" ]] && name=${BASH_REMATCH[1]} || continue
        [[ $line =~ SIZE=\"([0-9]*)\" ]] && size=${BASH_REMATCH[1]} || continue
        [[ $line =~ TYPE=\"([^\"]*)\" ]] && type=${BASH_REMATCH[1]} || continue
        [[ $line =~ RM=\"([01])\" ]] && rm=${BASH_REMATCH[1]} || rm=0
        [[ $line =~ RO=\"([01])\" ]] && ro=${BASH_REMATCH[1]} || ro=0
        model=""; [[ $line =~ MODEL=\"([^\"]*)\" ]] && model=${BASH_REMATCH[1]}
        tran=""; [[ $line =~ TRAN=\"([^\"]*)\" ]] && tran=${BASH_REMATCH[1]//[^a-z0-9]/}
        pt=""; [[ $line =~ PTTYPE=\"([^\"]*)\" ]] && pt=${BASH_REMATCH[1]}
        [[ $type == disk && $rm == 0 && $ro == 0 && $name == /dev/* && $size -gt 0 ]] || continue
        [[ $tran == usb ]] && continue
        [[ $pt == gpt || $pt == dos ]] || continue
        psum=0
        while read -r s t; do
            [[ $t == part && $s =~ ^[0-9]+$ ]] && (( psum += s ))
        done < <(lsblk -bnrpo SIZE,TYPE "$name" 2>/dev/null)
        # 2 MiB at the start, the GPT copy at the end
        s=$(( size - psum - 3 * 1048576 ))
        (( s < 0 )) && s=0
        DISKS+=("$name") DISK_FREE+=("$s")
        human_size "$size"
        DISK_DESC+=("${model//[[:cntrl:]]/ } ($_HS${tran:+, $tran})")
    done < <(lsblk -bdnPp -o NAME,SIZE,TYPE,RM,RO,MODEL,TRAN,PTTYPE 2>/dev/null)
}

# Disks with at least $1 GiB free -> DISK_OK (indices into DISKS)
disks_with_room() {
    local i need=$(( $1 * 1073741824 ))
    DISK_OK=()
    for i in "${!DISKS[@]}"; do (( DISK_FREE[i] >= need )) && DISK_OK+=("$i"); done
}

# Transport of disk $1 (usb, sata, nvme, ...)
disk_tran() {
    local t
    t=$(lsblk -dno TRAN "$1" 2>/dev/null)
    printf '%s' "${t//[^a-z0-9]/}"
}

# The largest unpartitioned stretch of disk $1 (root) -> GAP_START GAP_SECTORS SECTOR (in units
# of the disk's logical sector size)
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

# ── The record of our partition ───────────────────────────────────────────────────

# $DUAL_STATE -> ST_TARGET ST_DISK ST_PARTUUID ST_FSUUID (only well-formed values)
state_read() {
    local k v
    ST_TARGET="" ST_DISK="" ST_PARTUUID="" ST_FSUUID=""
    [[ -f $DUAL_STATE ]] || return 1
    while IFS='=' read -r k v; do
        case $k in
            target)   [[ $v =~ ^[a-z]+$ ]] && ST_TARGET=$v ;;
            disk)     [[ $v =~ ^/dev/[A-Za-z0-9/_-]+$ ]] && ST_DISK=$v ;;
            partuuid) [[ $v =~ ^[A-Fa-f0-9-]+$ ]] && ST_PARTUUID=$v ;;
            fsuuid)   [[ $v =~ ^[A-Fa-f0-9-]+$ ]] && ST_FSUUID=$v ;;
        esac
    done < "$DUAL_STATE"
    [[ -n $ST_PARTUUID ]]
}

state_write() {
    mkdir -p "$STATE_DIR" || return 1
    printf 'target=%s\ndisk=%s\npartuuid=%s\nfsuuid=%s\n' "$ST_TARGET" "$ST_DISK" "$ST_PARTUUID" "$ST_FSUUID" \
        > "$DUAL_STATE.new" && mv -f "$DUAL_STATE.new" "$DUAL_STATE"
}

# The partition of the record is there (without root, from udev's view) -> PART
state_part_seen() {
    local n u
    PART=""
    state_read || return 1
    while read -r n u; do
        [[ ${u,,} == "${ST_PARTUUID,,}" ]] && { PART=$n; return 0; }
    done < <(lsblk -nrpo NAME,PARTUUID 2>/dev/null)
    return 1
}

# The partition of the record -> PART (root: blkid reads the partition table itself)
find_ours() {
    PART=""
    state_read || return 1
    PART=$(as_root blkid -t "PARTUUID=$ST_PARTUUID" -o device 2>/dev/null | head -1)
    [[ -b $PART ]] || { PART=""; return 1; }
}

# PART still has the file system this installer made (or none at all yet: the run stopped before
# mkfs). Anything else means another installer used it: never formatted or deleted then.
part_still_ours() {
    local u
    u=$(as_root blkid -s UUID -o value "$PART" 2>/dev/null)
    if [[ -n $ST_FSUUID ]]; then
        [[ $u == "$ST_FSUUID" ]]
    else
        [[ -z $u && -z $(as_root blkid -s TYPE -o value "$PART" 2>/dev/null) ]]
    fi
}

# Number of partition $1 on its disk -> PART_NUM, its disk -> PART_DISK
part_pos() {
    local d
    PART_NUM=$(cat "/sys/class/block/${1##*/}/partition" 2>/dev/null)
    d=$(lsblk -dno PKNAME "$1" 2>/dev/null)
    PART_DISK=/dev/${d//[^A-Za-z0-9_-]/}
    [[ $PART_NUM =~ ^[0-9]+$ && -b $PART_DISK ]]
}

# Makes a partition of $2 bytes at the END of the largest free stretch of disk $1 -> PART, and
# records it. The partition table is saved first; nothing that exists is touched.
make_partition() {
    local disk=$1 bytes=$2 type=$3 probe out rc ptt ss sectors start end n dump i f part_number
    # GRUB must see the disk: one it cannot address ("cannot find a GRUB drive") could not boot
    # the installer entry. Checked before anything is written.
    if command -v grub-probe >/dev/null; then
        probe=$(as_root grub-probe -t drive -d "$disk" 2>&1) || {
            warn "GRUB cannot address $disk (often a USB disk or one the firmware does not list): choose another disk. grub-probe said: ${probe//[[:cntrl:]]/ }"
            return 1; }
        say "GRUB addresses $disk as ${probe//[[:cntrl:]]/ }"
    fi
    ptt=$(lsblk -dno PTTYPE "$disk" 2>/dev/null)
    case $ptt in gpt|dos) ;; *) warn "$disk has no GPT or MBR partition table (${ptt:-none})"; return 1 ;; esac
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
        # MBR: four primary slots (an extended partition takes one)
        n=0
        for f in /sys/class/block/"${disk##*/}"/*/partition; do
            [[ -r $f ]] && (( $(< "$f") <= 4 )) && (( n++ ))
        done
        (( n >= 4 )) && { warn "$disk has 4 primary partitions: no room for another"; return 1; }
        case $type in
            linux) type=83 ;;
            fat)   type=c ;;
        esac
    else
        case $type in
            linux) type=0FC63DAF-8483-4772-8E79-3D69D8477DE4 ;;
            fat)   type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 ;;
        esac
    fi
    # the old table, to put back with: sfdisk --no-reread DISK < FILE. Without it nothing is written.
    mkdir -p "$STATE_DIR" || return 1
    dump=$STATE_DIR/partition-table-${disk##*/}-$STAMP.sfdisk
    if ! as_root sfdisk --dump "$disk" > "$dump" 2>/dev/null || [[ ! -s $dump ]]; then
        warn "could not save the partition table of $disk: nothing changed"
        return 1
    fi
    say "partition table saved: $dump"
    note "Partition table of $disk before the change: ${dump/#$HOME/\~} (sudo sfdisk --no-reread $disk < FILE puts it back)."
    detail "partitioning $disk"
    # The disk is in use (this system lives on it): sfdisk would refuse to write it, and the kernel
    # cannot re-read the whole table. A partition in free space touches nothing that exists, so the
    # table is written without the re-read and the kernel is told about the new one (partx).
    out=$(printf 'start=%d, size=%d, type=%s\n' "$start" "$sectors" "$type" |
          as_root sfdisk --append --no-reread --no-tell-kernel -q "$disk" 2>&1)
    rc=$?
    printf '%s\n' "$out"
    # what counts is the table on the disk (some versions report the busy disk as an error)
    PART=""
    while read -r f out; do
        [[ $f == /dev/* && $out =~ start=\ *$start, ]] && { PART=$f; break; }
    done < <(as_root sfdisk --dump "$disk" 2>/dev/null)
    [[ -n $PART ]] || { warn "sfdisk did not write the partition ($rc): ${out//[[:cntrl:]]/ }"; return 1; }
    (( rc )) && say "sfdisk reported an error, but the partition is in the table: going on"
    part_number=${PART##*[!0-9]}
    as_root partx -a --nr "$part_number" "$disk" >/dev/null 2>&1
    as_root udevadm settle 2>/dev/null
    for (( i = 0; i < 15; i++ )); do
        [[ -b $PART ]] && break
        as_root partx -a --nr "$part_number" "$disk" >/dev/null 2>&1
        sleep 1
    done
    [[ -b $PART ]] || { warn "the new partition $PART did not show up: restart and run the installer again"; return 1; }
    ST_TARGET=$DUAL_TARGET ST_DISK=$disk ST_FSUUID=""
    ST_PARTUUID=$(as_root blkid -s PARTUUID -o value "$PART" 2>/dev/null)
    [[ $ST_PARTUUID =~ ^[A-Fa-f0-9-]+$ ]] || { warn "no PARTUUID for $PART"; return 1; }
    state_write || return 1
    say "partition $PART: $(( sectors * ss / 1048576 )) MB (PARTUUID $ST_PARTUUID)"
}

# Formats PART as $1 (ext4, vfat) and records the file system UUID -> ST_FSUUID
format_part() {
    local fs=$1
    detail "formatting $PART"
    case $fs in
        ext4) as_root mkfs.ext4 -q -F -L "$ISO_LABEL" "$PART" || return 1 ;;
        vfat) as_root mkfs.vfat -F 32 -n "$WIN_LABEL" "$PART" >/dev/null || return 1 ;;
    esac
    as_root udevadm settle 2>/dev/null
    ST_FSUUID=$(as_root blkid -s UUID -o value "$PART" 2>/dev/null)
    [[ $ST_FSUUID =~ ^[A-Fa-f0-9-]+$ ]] || { warn "no file system UUID for $PART"; return 1; }
    state_write
}

# ── Signatures ────────────────────────────────────────────────────────────────────
# Every distribution signs its checksum list (Arch, Alpine: the ISO itself). Only a signature by
# one of these primary keys counts, wherever the key was fetched from. Fingerprints from
# archlinux.org/download, debian.org/CD/verify, ubuntu.com/tutorials/how-to-verify-ubuntu and
# alpinelinux.org/keys/ncopa.asc. Fedora signs every release with a new key: its keys come from
# fedoraproject.org (not the download server), and the signer must be the key of exactly that
# release ("Fedora (44)").
declare -A OS_SIGNERS=(
    [arch]=3E80CA1A8B89F69CBA57D98A76A5EF9054449A5C
    [debian]="DF9B9C49EAA9298432589D76DA87E80D6294BE9B 10460DAD76165AD81FBC0CE9988021A964E6EA7D"
    [ubuntu]=843938DF228D22F7B3742BC0D94AA3F0EFE21092
    [alpine]=0482D84022F52DF1C4E7CD43293ACD0907D9495A
)
# where the keys come from (wkd: = the web key directory of that address); what is still
# missing then comes from the key server
declare -A OS_KEYSRC=(
    [arch]=wkd:pierre@archlinux.org
    [debian]="https://www.debian.org/CD/key-DA87E80D6294BE9B.txt https://www.debian.org/CD/key-988021A964E6EA7D.txt"
    [alpine]=https://alpinelinux.org/keys/ncopa.asc
    [fedora]=https://fedoraproject.org/fedora.gpg
)
KEYSERVER=hkps://keyserver.ubuntu.com
GPGH=""

# A keyring of its own for this run -> GPGH (mktemp -d: 0700); gpg_stop removes it again
gpg_start() { GPGH=$(mktemp -d) || { GPGH=""; return 1; }; }
gpg_stop() {
    [[ -n $GPGH ]] || return 0
    gpgconf --homedir "$GPGH" --kill all 2>/dev/null
    rm -rf -- "$GPGH"
    GPGH=""
}
pgp() { gpg --homedir "$GPGH" --batch --no-tty --quiet "$@"; }

# The signing keys of system $1 into that keyring
os_keys() {
    local src f
    detail "fetching the signing key of ${OS_TITLE[$1]}"
    for src in ${OS_KEYSRC[$1]-}; do
        case $src in
            wkd:*) pgp --auto-key-locate clear,wkd --locate-keys "${src#wkd:}" >/dev/null 2>&1 ;;
            *)     "${CURL_SAFE[@]}" "$src" 2>/dev/null | pgp --import >/dev/null 2>&1 ;;
        esac
    done
    for f in ${OS_SIGNERS[$1]-}; do
        pgp --list-keys "$f" >/dev/null 2>&1 || pgp --keyserver "$KEYSERVER" --recv-keys "$f" >/dev/null 2>&1
    done
}

# The signature of file $1 by system $2: detached in file $3, or (no $3) $1 is clearsigned and
# its signed text goes to $4. $5: the Fedora release. True if it is good and made by a key of
# that system.
sig_check() {
    local file=$1 id=$2 sig=${3-} out=${4-} rel=${5-} st fpr f
    if [[ -n $sig ]]; then
        st=$(pgp --status-fd 1 --verify "$sig" "$file" 2>/dev/null)
    else
        # exactly one signed message: nothing next to it that could pass for signed text
        [[ $(grep -c '^-----BEGIN PGP SIGNED MESSAGE-----' "$file") == 1 ]] || return 1
        st=$(pgp --status-fd 1 --yes --output "$out" --decrypt "$file" 2>/dev/null)
    fi
    grep -q '^\[GNUPG:\] BADSIG ' <<< "$st" && return 1
    grep -q '^\[GNUPG:\] GOODSIG ' <<< "$st" || return 1
    # VALIDSIG <fingerprint> <8 fields> <fingerprint of the primary key>
    while read -r fpr; do
        [[ $fpr =~ ^[0-9A-F]{40}$ ]] || continue
        for f in ${OS_SIGNERS[$id]-}; do [[ $fpr == "$f" ]] && return 0; done
        if [[ $id == fedora && $rel =~ ^[0-9]+$ ]] && pgp --with-colons --list-keys "$fpr" 2>/dev/null |
                awk -F: -v u="Fedora ($rel) <fedora-$rel-primary@fedoraproject.org>" \
                    '$1 == "uid" && $2 != "r" && $10 == u {ok = 1} END {exit !ok}'; then
            return 0
        fi
    done < <(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {print $NF}' <<< "$st")
    return 1
}

# Downloads URL $1 to the keyring directory as $2, for checking
sig_fetch() { "${CURL_SAFE[@]}" -o "$GPGH/$2" "$1"; }

# ── ISO sources ───────────────────────────────────────────────────────────────────

# os_resolve ID -> ISO_URL ISO_SHA, ISO_SIG_URL (Arch, Alpine: the signature of the ISO itself,
# checked after the download); ISO_ERR says what went wrong. Needs gpg_start. The checksum
# lists of Debian, Ubuntu and Fedora are signed: they count only with a good signature.
os_resolve() {
    local base sums line n h
    ISO_URL="" ISO_SHA="" ISO_SIG_URL="" ISO_ERR=""
    os_keys "$1"
    case $1 in
        arch)
            base=https://geo.mirror.pkgbuild.com/iso/latest
            sums=$("${CURL_SAFE[@]}" "$base/sha256sums.txt") || return 1
            ISO_SHA=$(awk '$2 == "archlinux-x86_64.iso" {print $1; exit}' <<< "$sums")
            ISO_URL=$base/archlinux-x86_64.iso ISO_SIG_URL=$base/archlinux-x86_64.iso.sig ;;
        debian)
            base=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
            sig_fetch "$base/SHA256SUMS" sums && sig_fetch "$base/SHA256SUMS.sign" sums.sig || return 1
            sig_check "$GPGH/sums" debian "$GPGH/sums.sig" || { ISO_ERR="the checksum list is not signed by the Debian CD key"; return 1; }
            sums=$(< "$GPGH/sums")
            line=$(grep -E '^[0-9a-f]{64}  debian-[0-9][0-9.]*-amd64-netinst\.iso$' <<< "$sums" | head -1)
            ISO_SHA=${line%% *}; n=${line##* }
            ISO_URL=$base/$n ;;
        ubuntu)
            # the newest supported LTS (its code name), then its newest point release
            n=$("${CURL_SAFE[@]}" https://changelogs.ubuntu.com/meta-release-lts |
                awk '/^Dist: / {d = $2} /^Supported: 1/ {s = d} END {print s}')
            [[ $n =~ ^[a-z]+$ ]] || return 1
            base=https://releases.ubuntu.com/$n
            sig_fetch "$base/SHA256SUMS" sums && sig_fetch "$base/SHA256SUMS.gpg" sums.sig || return 1
            sig_check "$GPGH/sums" ubuntu "$GPGH/sums.sig" || { ISO_ERR="the checksum list is not signed by the Ubuntu CD image key"; return 1; }
            sums=$(< "$GPGH/sums")
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
            sig_fetch "$base/$(sed 's/Workstation-Live-\([0-9][0-9]*\)-\([0-9.]*\)\.x86_64\.iso/Workstation-\1-\2-x86_64-CHECKSUM/' <<< "$h")" sums || return 1
            # clearsigned: only the text the signature covers counts
            sig_check "$GPGH/sums" fedora "" "$GPGH/sums.txt" "$n" || { ISO_ERR="the checksum list is not signed by the key of Fedora $n"; return 1; }
            sums=$(< "$GPGH/sums.txt")
            ISO_SHA=$(sed -n "s/^SHA256 ($h) = \([0-9a-f]\{64\}\)\$/\1/p" <<< "$sums")
            ISO_URL=$base/$h ;;
        alpine)
            base=https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64
            sums=$("${CURL_SAFE[@]}" "$base/latest-releases.yaml") || return 1
            line=$(awk '/flavor: alpine-standard$/ {f=1} f && /^  file:/ {n=$2} f && /^  sha256:/ {print $2, n; exit}' <<< "$sums")
            ISO_SHA=${line%% *}; n=${line##* }
            ISO_URL=$base/$n ISO_SIG_URL=$base/$n.asc ;;
        *) return 1 ;;
    esac
    [[ $ISO_SHA =~ ^[0-9a-f]{64}$ && $ISO_URL =~ ^https://[A-Za-z0-9./_-]+\.iso$ ]]
}

# Size of the file at URL $1 in bytes -> ISO_BYTES (0: unknown)
url_size() {
    ISO_BYTES=$("${CURL_SAFE[@]}" -I -L "$1" 2>/dev/null | tr -d '\r' | awk 'tolower($1) == "content-length:" {n = $2} END {print n + 0}')
    [[ $ISO_BYTES =~ ^[0-9]+$ ]] || ISO_BYTES=0
}

# Downloads $1 to $2 as the user (resumes a partial file), with @@progress. $3: expected size
download_to() {
    local url=$1 dst=$2 total=${3:-0} pid size
    detail "downloading ${url##*/}"
    curl -fL --proto '=https' --tlsv1.2 --retry 5 --retry-delay 5 --connect-timeout 20 \
        --speed-limit 1024 --speed-time 120 -C - -sS -o "$dst" "$url" &
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

# SHA-256 of file $1 is ISO_SHA
sha_ok() {
    local sum
    detail "checking the SHA-256 of ${1##*/}"
    sum=$(sha256sum "$1" 2>/dev/null) || return 1
    [[ ${sum%% *} == "$ISO_SHA" ]]
}

# ── GRUB entry ────────────────────────────────────────────────────────────────────

# Installs /etc/grub.d/45_dotfiles_iso with the entry ENTRY
grub_entry_install() {
    local tmp rc
    tmp=$(mktemp) || return 1
    { printf '#!/bin/sh\n# dotfiles install.sh: boots the installer of a second system from its partition\n'
      printf 'exec tail -n +4 "$0"\n'
      printf '%s\n' "$ENTRY"; } > "$tmp"
    as_root install -m755 -T -- "$tmp" "$GRUB_ISO_ENTRY"; rc=$?
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
    if (( ${OS_WIN[$id]:-0} )); then
        PLAN+=("Windows: ${WIN_ISO:+${WIN_ISO##*/}, }copied onto a FAT32 partition, install.wim split for it")
    else
        PLAN+=("${OS_TITLE[$id]}: download about $(( OS_MB[$id] / 1000 )).$(( OS_MB[$id] / 100 % 10 )) GB, the signature of ${OS_TITLE[$id]%% *} checked ($([[ $id == fedora ]] && echo "key of that release from fedoraproject.org" || echo "pinned key"))")
    fi
    PLAN+=("a GRUB entry \"Install ${OS_TITLE[$id]}\" boots its installer from that partition")
    PLAN+=("the rest of the free space ($OS_TOTAL GB needed in total) stays free for the installer of ${OS_TITLE[$id]}")
    [[ $BOOTLOADER == grub ]] || PLAN+=("!needs GRUB: the boot loader is $BOOTLOADER")
    (( ${OS_EXP[$id]:-0} )) && PLAN+=("!the boot line for ${OS_TITLE[$id]} is not tested on hardware")
    return 0
}

run_othersys() {
    local id=$DUAL_TARGET need bytes mnt fs ptype iso have ready=0 size
    [[ -n $id ]] || { say "no second system chosen"; return 0; }
    detect_boot
    [[ $BOOTLOADER == grub ]] || { warn "needs GRUB (boot loader: $BOOTLOADER)"; return 1; }
    command -v sfdisk >/dev/null && command -v partx >/dev/null || { warn "sfdisk or partx is missing (util-linux)"; return 1; }
    need=${OS_NEED[$id]}
    if (( ${OS_WIN[$id]:-0} )); then
        (( EFI )) || { warn "the Windows setup is prepared for UEFI only; this machine boots in BIOS mode"; return 1; }
        [[ -f $WIN_ISO && -r $WIN_ISO ]] || { warn "Windows ISO not found: ${WIN_ISO:-none given}"; return 1; }
        command -v wimlib-imagex >/dev/null || { warn "wimlib is missing (package wimlib)"; return 1; }
        command -v mkfs.vfat >/dev/null || { warn "mkfs.vfat is missing (package dosfstools)"; return 1; }
        fs=vfat ptype=fat
        bytes=$(stat -c %s "$WIN_ISO") || return 1
    else
        fs=ext4 ptype=linux
        command -v gpg >/dev/null || { warn "gpg is missing (package gnupg): the signature cannot be checked"; return 1; }
        gpg_start || return 1
        trap gpg_stop EXIT
        detail "asking the server"
        os_resolve "$id" || { warn "${OS_TITLE[$id]}: ${ISO_ERR:-could not read the download and checksum from the server}"; return 1; }
        url_size "$ISO_URL"
        say "${OS_TITLE[$id]}: $ISO_URL"
        bytes=$ISO_BYTES
        (( bytes > 0 )) || bytes=$(( OS_MB[$id] * 1048576 ))
    fi
    # the ISO (Alpine: twice, it is unpacked as well) and room to work
    [[ $id == alpine ]] && bytes=$(( bytes * 2 ))
    bytes=$(( bytes + 1073741824 ))

    # the partition of an earlier run (the download resumes there)
    if find_ours; then
        if [[ $ST_TARGET != "$id" ]]; then
            warn "There is an installer partition for ${OS_TITLE[$ST_TARGET]:-$ST_TARGET} already ($PART): run ./install.sh dualboot-clean first."
            return 1
        fi
        if ! part_still_ours; then
            warn "$PART (the installer partition of an earlier run) has another file system now: did an installer use it? Left alone; ./install.sh dualboot-clean forgets it."
            return 1
        fi
        size=$(as_root blockdev --getsize64 "$PART" 2>/dev/null)
        if [[ ! $size =~ ^[0-9]+$ ]] || (( size < bytes - 268435456 )); then
            warn "The installer partition $PART is too small for this ISO: run ./install.sh dualboot-clean, then the installer again."
            return 1
        fi
        say "the installer partition of an earlier run is $PART: using it"
        # no file system yet (the earlier run stopped before mkfs)
        [[ -n $ST_FSUUID ]] || format_part "$fs" || return 1
    else
        [[ -n $ST_PARTUUID ]] && say "the installer partition of an earlier run is gone: making a new one"
        [[ -b $DUAL_DISK ]] || { warn "disk not found: ${DUAL_DISK:-none chosen}"; return 1; }
        make_partition "$DUAL_DISK" "$bytes" "$ptype" || return 1
        format_part "$fs" || return 1
        # the new system needs room besides it
        largest_gap "$DUAL_DISK"
        if (( GAP_SECTORS * SECTOR < need * 1073741824 )); then
            warn "only $(( GAP_SECTORS * SECTOR / 1073741824 )) GB stay free for ${OS_TITLE[$id]} (it needs about $need GB): free more space, or remove the partition again with ./install.sh dualboot-clean"
        fi
    fi

    mnt=$(mktemp -d) || return 1
    # shellcheck disable=SC2064
    trap "as_root umount '$mnt' 2>/dev/null; rmdir '$mnt' 2>/dev/null; gpg_stop" EXIT
    as_root mount "$PART" "$mnt" || { warn "cannot mount $PART"; return 1; }

    if (( ${OS_WIN[$id]:-0} )); then
        prepare_windows "$mnt" || return 1
        ENTRY=$(cat <<EOF
menuentry "Install Windows (setup from the disk)" --class windows --id dotfiles-windows {
    insmod part_gpt
    insmod part_msdos
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $ST_FSUUID
    chainloader /efi/boot/bootx64.efi
}
EOF
)
    else
        # the download runs as you, not as root: the partition's top directory is yours
        as_root chown "$USER_NAME:" "$mnt" || return 1
        iso=$mnt/$id.iso
        # the file name is the same for every release: a partial download of an older one must
        # not be resumed with the new one (its checksum, from the earlier run, is next to it)
        if [[ -f $iso && -s $iso.sha256 && $(< "$iso.sha256") != "$ISO_SHA" ]]; then
            rm -f "$iso"; say "$id.iso is of an older release: downloading the current one"
        fi
        if [[ -f $iso ]]; then
            have=$(stat -c %s "$iso" 2>/dev/null || echo 0)
            # complete (or of unknown size): its checksum decides; a stale or broken one goes
            if (( ISO_BYTES == 0 || have >= ISO_BYTES )); then
                if sha_ok "$iso"; then ready=1; say "$id.iso is there and its checksum is right"
                else rm -f "$iso"; say "$id.iso is outdated or broken: downloading it again"; fi
            fi
        fi
        if (( ! ready )); then
            printf '%s\n' "$ISO_SHA" > "$iso.sha256" || return 1
            download_to "$ISO_URL" "$iso" "$ISO_BYTES" || { warn "download failed (run the installer again to resume)"; return 1; }
            sha_ok "$iso" || { rm -f "$iso"; warn "the SHA-256 of $id.iso is wrong: deleted, run the installer again"; return 1; }
            say "$id.iso downloaded, checksum right"
        fi
        # Arch, Alpine: their checksum list is not signed, the ISO is
        if [[ -n $ISO_SIG_URL ]]; then
            detail "checking the signature of $id.iso"
            sig_fetch "$ISO_SIG_URL" iso.sig || { warn "cannot download the signature of $id.iso"; return 1; }
            if ! sig_check "$iso" "$id" "$GPGH/iso.sig"; then
                rm -f "$iso"
                warn "$id.iso is not signed by the key of ${OS_TITLE[$id]}: deleted"
                return 1
            fi
        fi
        say "$id.iso: signature of ${OS_TITLE[$id]} good"
        linux_entry "$id" "$iso" "$mnt" || return 1
    fi
    as_root sync
    as_root umount "$mnt" && rmdir "$mnt"
    trap - EXIT
    gpg_stop

    grub_entry_install || return 1
    say "GRUB entry: $GRUB_ISO_ENTRY"
    grub_regen || return 1
    note "${OS_TITLE[$id]}: restart and choose \"Install ${OS_TITLE[$id]%% *} ...\" in the GRUB menu. Its installer offers the free space on the disk; leave the installer partition ($PART) alone until the new system is installed."
    note "${OS_TITLE[$id]}: once it is installed, run ./install.sh dualboot-clean (removes the menu entry and the installer partition), then ./install.sh modules dualboot (puts the new system in the menu)."
    (( ${OS_WIN[$id]:-0} )) && note "Windows: its setup puts \"Windows Boot Manager\" first in the firmware boot order. Choose Void once in the firmware boot menu, then put it first again: sudo efibootmgr -o <Void's number>,<the others>."
    need_reboot
    return 0
}

# GRUB entry of Linux system $1 (ISO $2, partition mounted at $3) -> ENTRY
linux_entry() {
    local id=$1 iso=$2 mnt=$3 label tmp rc
    local head="    insmod part_gpt
    insmod part_msdos
    insmod ext2
    insmod loopback
    insmod iso9660
    search --no-floppy --fs-uuid --set=isodev $ST_FSUUID"
    ENTRY=""
    case $id in
        arch|debian|ubuntu)
            # these ISOs bring a loopback.cfg for exactly this (it reads iso_path)
            ENTRY=$(cat <<EOF
menuentry "Install ${OS_TITLE[$id]} (installer from the disk)" --class $id --id dotfiles-$id {
$head
    set iso_path="/$id.iso"
    export iso_path
    loopback loop (\$isodev)\$iso_path
    set root=(loop)
    configfile /boot/grub/loopback.cfg
}
EOF
)
            ;;
        fedora)
            label=$(blkid -p -s LABEL -o value "$iso" 2>/dev/null)
            [[ $label =~ ^[A-Za-z0-9._-]+$ ]] || { warn "cannot read the volume label of the ISO (${label//[[:cntrl:]]/ })"; return 1; }
            ENTRY=$(cat <<EOF
menuentry "Install Fedora (installer from the disk)" --class fedora --id dotfiles-fedora {
$head
    loopback loop (\$isodev)/fedora.iso
    linux (loop)/images/pxeboot/vmlinuz root=live:CDLABEL=$label iso-scan/filename=/fedora.iso rd.live.image quiet
    initrd (loop)/images/pxeboot/initrd.img
}
EOF
)
            ;;
        alpine)
            # unpacked onto the partition like a boot stick (setup-bootable): Alpine's initramfs
            # looks for boot/ and apks/ on the device, not for an ISO
            detail "unpacking the Alpine ISO"
            tmp=$(mktemp -d) || return 1
            as_root mount -o loop,ro "$iso" "$tmp" || { rmdir "$tmp"; warn "cannot mount the ISO"; return 1; }
            as_root cp -a "$tmp"/. "$mnt"/; rc=$?
            as_root umount "$tmp"; rmdir "$tmp"
            (( rc == 0 )) || { warn "copying the Alpine ISO failed"; return 1; }
            ENTRY=$(cat <<EOF
menuentry "Install Alpine (installer from the disk)" --class alpine --id dotfiles-alpine {
    insmod part_gpt
    insmod part_msdos
    insmod ext2
    search --no-floppy --fs-uuid --set=root $ST_FSUUID
    linux /boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage,nvme,ext4 alpine_dev=UUID=$ST_FSUUID modloop=/boot/modloop-lts quiet
    initrd /boot/initramfs-lts
}
EOF
)
            ;;
        *) return 1 ;;
    esac
}

# The Windows ISO $WIN_ISO onto the FAT32 partition mounted at $1
prepare_windows() {
    local dst=$1 src wim size rc
    src=$(mktemp -d) || return 1
    detail "mounting the Windows ISO"
    as_root mount -o loop,ro "$WIN_ISO" "$src" || { rmdir "$src"; warn "cannot mount $WIN_ISO (is it an ISO?)"; return 1; }
    # read as root: UDF keeps the permissions of the disc
    wim=$(as_root find "$src" -maxdepth 2 -ipath '*/sources/install.wim' | head -1)
    [[ -z $wim ]] && wim=$(as_root find "$src" -maxdepth 2 -ipath '*/sources/install.esd' | head -1)
    if [[ -z $wim ]] || ! as_root find "$src" -maxdepth 3 -ipath '*/efi/boot/bootx64.efi' | grep -q .; then
        as_root umount "$src"; rmdir "$src"
        warn "this is not a 64-bit UEFI Windows installation ISO (sources/install.wim or efi/boot/bootx64.efi missing)"
        return 1
    fi
    size=$(as_root stat -c %s "$wim")
    [[ $size =~ ^[0-9]+$ ]] || size=0
    if [[ $wim == *.esd ]] && (( size >= 4294967295 )); then
        as_root umount "$src"; rmdir "$src"
        warn "install.esd is larger than 4 GB and cannot be split for FAT32: use an ISO with install.wim"
        return 1
    fi
    detail "copying the files"
    as_root tar cf - -C "$src" --exclude="${wim#"$src"/}" . | as_root tar xf - -C "$dst" --no-same-owner --no-same-permissions
    rc=$(( PIPESTATUS[0] || PIPESTATUS[1] ))
    if (( rc )); then
        as_root umount "$src"; rmdir "$src"; warn "copying the Windows files failed"; return 1
    fi
    as_root mkdir -p "$dst/sources"
    if (( size >= 4294967295 )); then
        detail "splitting install.wim for FAT32"
        as_root wimlib-imagex split "$wim" "$dst/sources/install.swm" 3800 >/dev/null || { as_root umount "$src"; rmdir "$src"; warn "wimlib-imagex split failed"; return 1; }
    else
        detail "copying ${wim##*/}"
        as_root cp "$wim" "$dst/sources/${wim##*/}" || { as_root umount "$src"; rmdir "$src"; return 1; }
    fi
    as_root umount "$src"; rmdir "$src"
    say "the Windows setup files are on the partition"
}

# ── Remove again (./install.sh dualboot-clean) ────────────────────────────────────

# Partitions an earlier version of this installer made without a record: in the current table,
# not in the oldest saved table of that disk, and either without a file system or with our label
# (a system installed into the free space since then has its own file system: never offered)
# -> LEFTOVERS
find_leftovers() {
    local dump disk f out fstype label
    local -A seen=() old=()
    LEFTOVERS=()
    # sorted by name: per disk, the oldest table (its time stamp) comes first
    for dump in "$STATE_DIR"/partition-table-*.sfdisk; do
        [[ -f $dump ]] || continue
        disk=$(sed -n 's/^device: \(\/dev\/[A-Za-z0-9\/_-]*\)$/\1/p' "$dump" | head -1)
        [[ -n $disk && -z ${seen[$disk]-} && -b $disk ]] || continue
        seen[$disk]=1
        old=()
        while read -r f out; do
            [[ $f == /dev/* && $out =~ start=\ *([0-9]+), ]] && old[${BASH_REMATCH[1]}]=1
        done < "$dump"
        while read -r f out; do
            [[ $f == /dev/* && $out =~ start=\ *([0-9]+), ]] || continue
            [[ -n ${old[${BASH_REMATCH[1]}]-} || $f == "$PART" ]] && continue
            # only the types this installer makes (Linux data, Microsoft basic data): never an MSR or
            # BIOS boot partition another installer made (they have no file system either)
            [[ ${out^^} =~ TYPE=(0FC63DAF-8483-4772-8E79-3D69D8477DE4|EBD0A0A2-B9E5-4433-87C0-68B6B72699C7|83|C)(,|$) ]] || continue
            fstype=$(sudo blkid -s TYPE -o value "$f" 2>/dev/null)
            label=$(sudo blkid -s LABEL -o value "$f" 2>/dev/null)
            [[ -z $fstype || $label == "$ISO_LABEL" || $label == "$WIN_LABEL" ]] && LEFTOVERS+=("$f")
        done < <(sudo sfdisk --dump "$disk" 2>/dev/null)
    done
}

# Deletes partition $1 (asks nothing; the caller did). Refuses a mounted one.
delete_part() {
    local mp
    mp=$(findmnt -rno TARGET -S "$1" 2>/dev/null | head -1)
    [[ -z $mp ]] || { echo "$1 is mounted at $mp: unmount it first, then run this again." >&2; return 1; }
    if part_pos "$1" && sudo sfdisk --delete --no-reread --no-tell-kernel "$PART_DISK" "$PART_NUM" >/dev/null 2>&1; then
        sudo partx -d --nr "$PART_NUM" "$PART_DISK" 2>/dev/null
        echo "deleted $1"
        return 0
    fi
    echo "could not delete $1 (sudo sfdisk --delete DISK NUMBER)" >&2
    return 1
}

dualboot_clean() {
    local answer cfg f fstype changed=0
    [[ -t 0 ]] || { echo "dualboot-clean asks before it deletes: run it in a terminal." >&2; return 1; }
    command -v sudo >/dev/null || { echo "sudo is not installed" >&2; return 1; }
    sudo -v || return 1
    PART=""
    if state_read && find_ours && ! part_still_ours; then
        echo "$PART (the installer partition of the record) has another file system now: an installer used it."
        echo "It is left alone; the record is removed."
        PART=""
        rm -f "$DUAL_STATE"
    fi
    find_leftovers
    if [[ -z $PART && ! -e $GRUB_ISO_ENTRY && ${#LEFTOVERS[@]} -eq 0 ]]; then
        echo "Nothing to remove: no installer entry, no installer partition of this installer."
        rm -f "$DUAL_STATE"
        sudo -k
        return 0
    fi
    echo "This removes:"
    [[ -e $GRUB_ISO_ENTRY ]] && echo "  the boot menu entry $GRUB_ISO_ENTRY"
    if [[ -n $PART ]]; then
        human_size "$(sudo blockdev --getsize64 "$PART" 2>/dev/null || echo 0)"
        echo "  the installer partition $PART ($_HS, ${OS_TITLE[$ST_TARGET]:-$ST_TARGET} installer, PARTUUID $ST_PARTUUID)"
    fi
    echo "The new system and everything else stay."
    if [[ -e $GRUB_ISO_ENTRY || -n $PART ]]; then
        read -rp "Remove? [y/N] " answer
        if [[ $answer == [yYjJ]* ]]; then
            if [[ -e $GRUB_ISO_ENTRY ]] && sudo rm -f -- "$GRUB_ISO_ENTRY"; then
                echo "removed $GRUB_ISO_ENTRY"; changed=1
            fi
            if [[ -n $PART ]]; then
                delete_part "$PART" && { rm -f "$DUAL_STATE"; changed=1; }
            else
                rm -f "$DUAL_STATE"
            fi
        else
            echo "Nothing changed."
        fi
    fi
    # an earlier version made partitions without a record: one by one
    for f in "${LEFTOVERS[@]}"; do
        human_size "$(sudo blockdev --getsize64 "$f" 2>/dev/null || echo 0)"
        fstype=$(sudo blkid -s TYPE -o value "$f" 2>/dev/null)
        echo
        echo "$f ($_HS, ${fstype:-no file system}) was not on the disk when the installer first saved its partition table:"
        echo "probably an installer partition of an earlier run."
        read -rp "Delete $f? [y/N] " answer
        [[ $answer == [yYjJ]* ]] && delete_part "$f" && changed=1
    done
    if (( changed )) && command -v grub-mkconfig >/dev/null; then
        cfg=/boot/grub/grub.cfg
        sudo test -e /boot/grub2/grub.cfg && cfg=/boot/grub2/grub.cfg
        echo "making the boot menu again"
        sudo grub-mkconfig -o "$cfg" 2>&1 | grep -E '^(Found|done)'
    fi
    sudo -k
}
