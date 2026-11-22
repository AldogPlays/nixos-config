# Installation

I use bootstrap to adopt an existing NixOS installation with my desktop
settings. It preserves that machine's hardware configuration; it does not
partition disks, format filesystems, or perform the initial NixOS installation.

## Requirements

I start from a machine with:

- An installed x86-64 NixOS system; 26.05 is the reference release.
- An existing normal desktop account with sudo access and a mutable password.
- A conventional `/etc/nixos/configuration.nix` and its hardware configuration.
- Network access to the repository, pinned inputs and package caches.
- A separate backup of personal data and a working way to select a previous
  NixOS generation if activation fails.

My package set includes unfree software. Cisco Packet Tracer is optional:
bootstrap continues without it when its installer is unavailable. To include it,
I download `CiscoPacketTracer_901_Ubuntu_64bit.deb` from [Cisco's Resource
Hub](https://www.netacad.com/resources/lab-downloads) into `~/Downloads` before
running bootstrap. Bootstrap checks its hash against the pinned package and
imports a matching download into the Nix store. A mismatched download is skipped
with a warning; an installer already in the store needs no download.

The generated `project-host.json` records `packetTracerEnable`, so subsequent
rebuilds keep the selected package set. To add Packet Tracer later, I supply the
matching installer and rerun bootstrap. Installers and account credentials stay
outside Git. Other application sign-ins remain interactive after installation.

## Preview and apply

I run bootstrap as the existing desktop account, rather than starting the entire
command with sudo. The helper requests administrative access when installing the
verified configuration.

I preview the configuration with:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap
```

I can save the generated host files for inspection:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap -- --output /tmp/nixos-host-preview
```

After reviewing the preview and prerequisites, I apply it with:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap -- --apply
```

From my local checkout, I use `nix run .#bootstrap` and `nix run .#bootstrap --
--apply`. A preview evaluates and plans the system; it does not complete the
build or establish that the hardware will boot.

Activation may replace the existing login manager and affect the current desktop
session. Bootstrap does not reboot automatically. I select the Hyprland session
at my next login.

## Repository access

My repository is public, so the GitHub shorthand above needs no
private-repository credentials. I can also clone it and run bootstrap from the
checkout:

```bash
git clone https://github.com/AldogPlays/nixos-config.git
cd nixos-config
nix run .#bootstrap
```

I keep access tokens, SSH keys, and other credentials outside Nix expressions,
generated host files, and this repository.

## What bootstrap preserves

The helper reads the installed configuration using the project's pinned NixOS
modules and copies that installation's hardware configuration. It preserves:

- Login, home directory, hostname and the existing system compatibility baseline.
- Disk identifiers, mount topology, encryption and initrd style.
- Existing systemd-boot or GRUB/EFI settings.
- Standard graphics-driver choices, including supported NVIDIA branch/PRIME and
  VA-API package settings.

Shared desktop settings, power policies and caches come from this repository.
Bootstrap does not copy the Lenovo's UUIDs or automatically choose a proprietary
GPU driver for previously unconfigured hardware. Existing account passwords stay
on the installation. Personal files, wallpapers and application logins are
separate from the system configuration.

I use the checked-in `.#nixos` target only on my Lenovo. On another computer, I
use the generated host with that installation's own account and hardware.

## Build, backup and recovery

With `--apply`, I build the complete generation before privileged configuration
writes. Bootstrap prepares a sibling copy of `/etc/nixos`, including my original
files, and adds the generated host flake, lock file, settings JSON, and hardware
module there. It publishes the complete directory with an atomic exchange;
the previous directory becomes `/etc/nixos.pre-project-TIMESTAMP`.

A failed copy or unsupported exchange does not replace the active configuration.
I keep any incomplete preparation copy for inspection. If I interrupt publication,
I inspect both reported paths: the exchange selects either the complete old or
complete new directory, with no file-by-file mixture. This requires a filesystem
that supports atomic directory exchange; bootstrap stops rather than falling back
to a non-atomic copy.

Activation happens after publication. If it fails, I retain the complete new
configuration and the old backup for recovery; bootstrap does not automatically
roll back services that may already have changed. The original `configuration.nix`
and `hardware-configuration.nix` are preserved in both directories.

For systemd-boot, bootstrap attempts to clear a persistent EFI menu-timeout
override after activation when the host permits EFI-variable writes. If that
cleanup fails, it reports the successful activation separately and prints the
manual retry command. I hold Space during firmware startup to open the boot menu
and select an earlier generation. My [maintenance notes](maintenance.md#recovery)
cover runtime rollback and its limits.

The `/etc/nixos` backup contains configuration, not personal data. NixOS generation
rollback does not restore personal files. Home Manager preserves conflicting
files with a `.hm-backup` suffix; inspect them before removing anything.

## Updating a generated host

Generated hosts pin the exact project source in the Nix store. The
`/etc/nixos-project-source` link keeps that snapshot reachable through the system
closure, including when the source repository requires authentication.

The generated `rebuild` alias uses `/etc/nixos#nixos`. Rerun bootstrap from a newer
project revision to adopt later project changes; ordinary rebuilds keep the
previously selected source. Reruns recognize the generated host and back up its
current configuration again.

The theme menu stores generated-host preferences as `themeSelection` in
`/etc/nixos/project-host.json`. Bootstrap reruns preserve those preferences;
theme changes do not require editing the pinned project snapshot.

## Supported layouts and limits

Bootstrap stops rather than guessing when the installed release or compatibility
baseline is newer than the pinned 26.05 release, when another unrelated flake is
already present, or when accounts are immutable. Custom Secure Boot, mirrored
GRUB and custom graphics packages require an explicit host module.

I use `--configuration PATH` and `--hardware PATH` to select conventional input
files for a preview. NixOS modules are executable configuration: inspect and
trust them before evaluation. Arbitrary relative imports may require a dedicated
host module.

My local checks evaluate complete Intel/UEFI, AMD/BIOS, and NVIDIA
configurations and test account/disk isolation. I have previewed bootstrap on my
Lenovo, but have not completed a fresh VM or spare-PC activation trial. I do not
treat these checks as proof of boot or graphics behavior on every PC.
