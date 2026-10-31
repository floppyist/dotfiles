# kernelforge

A Linux kernel for this machine only. Part of the dotfiles (the installer's module "Custom kernel"), also
usable on its own.

```
kernelforge/bin/kernelforge --dry-run      # what would happen, changes nothing
kernelforge/bin/kernelforge                # build and install (asks for the version and sudo)
kernelforge/bin/kernelforge versions       # the versions kernel.org maintains
```

What it does, in this order (`lib/`):

1. `detect.sh`: CPU, root file system (LUKS?), boot loader (GRUB, systemd-boot), initramfs tool, Secure Boot.
2. `source.sh`: the version (default: the newest of the running series), the tarball and its signature from
   `cdn.kernel.org` over https. The signature must be from one of the pinned keys (Torvalds, Kroah-Hartman, Levin),
   checked in a private GnuPG home.
3. `config.sh`: the running configuration (`/proc/config.gz`), `olddefconfig`, `localmodconfig` against `lsmod`,
   a list of modules that stay anyway, `X86_NATIVE_CPU`, the release name `-kf` (`-kf2`, ... if it exists). It stops
   if the result lacks the root file system, `DM_CRYPT` for an encrypted root, or BTF.
4. `build.sh`: `make` as your user (nice 10, jobs by memory), modules into a staging directory.
5. `boot.sh`: the only part that uses root (sudo): modules to `/lib/modules/<release>`, `vmlinuz`, `System.map`,
   `config`, initramfs, boot entry. Nothing that exists is overwritten; on a failure what this run created is removed.

Environment: `KF_PROTOCOL=1` prints the installer's `@@` messages, `KF_NONINTERACTIVE=1` never asks (sudo -n).
Logs: `~/.local/state/kernelforge/`. Source and build: `~/.cache/kernelforge` (about 8 GB; delete it afterwards).
