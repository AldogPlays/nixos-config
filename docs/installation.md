# Installation

Bootstrap adopts an existing NixOS installation. It does not partition disks,
format filesystems or perform the initial NixOS installation.

## Requirements

- An installed x86-64 NixOS system; 26.05 is the reference release.
- An existing normal desktop account with sudo access and a mutable password.
- A conventional `/etc/nixos/configuration.nix` and its hardware configuration.
- Network access to the repository, pinned inputs and package caches.
- A separate backup of personal data and a working way to select a previous
  NixOS generation if activation fails.

The package set includes unfree software. Cisco Packet Tracer requires
`CiscoPacketTracer_901_Ubuntu_64bit.deb` from
[Cisco's Resource Hub](https://www.netacad.com/resources/lab-downloads).
Place it in `~/Downloads` before applying bootstrap. The wrapper checks its hash
against the pinned package and imports it into the Nix store; it does not commit
the installer or any account credentials. Other application sign-ins remain
interactive after installation.

## Preview and apply

Run as the existing desktop account, rather than starting the entire command
with sudo. The helper requests administrative access when installing the verified
configuration.

When the repository is public, preview with:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap
```

To save the generated host files for inspection:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap -- --output /tmp/nixos-host-preview
```

After reviewing the preview and prerequisites, apply with:

```bash
nix --extra-experimental-features 'nix-command flakes' run github:AldogPlays/nixos-config#bootstrap -- --apply
```

From an accessible checkout, the equivalent commands are `nix run .#bootstrap`
and `nix run .#bootstrap -- --apply`. A preview evaluates and plans the system;
it does not complete the build or establish that the hardware will boot.

Activation may replace the existing login manager and affect the current desktop
session. Bootstrap does not reboot automatically. Log into the Hyprland session
after activation when appropriate.

## Repository access

The GitHub shorthand above requires public access or suitable Nix authentication.
While the repository is private, an account with access can use SSH:

```bash
nix --extra-experimental-features 'nix-command flakes' run 'git+ssh://git@github.com/AldogPlays/nixos-config?ref=main#bootstrap' -- --apply
```

Alternatively, clone through an authenticated Git client and run bootstrap from
the checkout. Do not embed access tokens, SSH keys or other credentials in Nix
expressions, generated host files or this repository.

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

The checked-in `.#nixos` target is specific to the reference Lenovo. Never use it
as a replacement for the generated host on another computer.

## Build, backup and recovery

With `--apply`, bootstrap builds the complete generation before privileged
configuration writes. It copies `/etc/nixos` to
`/etc/nixos.pre-project-TIMESTAMP`, then installs a host flake, lock file,
settings JSON and copied hardware module. The original `configuration.nix` and
`hardware-configuration.nix` remain in place.

For systemd-boot, bootstrap clears a persistent EFI menu-timeout override when
EFI variables are writable. Hold Space during firmware startup to open the boot
menu and select an earlier generation. See [maintenance](maintenance.md#recovery)
for runtime rollback and its limits.

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

## Supported layouts and limits

Bootstrap stops rather than guessing when the installed release or compatibility
baseline is newer than the pinned 26.05 release, when another unrelated flake is
already present, or when accounts are immutable. Custom Secure Boot, mirrored
GRUB and custom graphics packages require an explicit host module.

Use `--configuration PATH` and `--hardware PATH` to select conventional input
files for a preview. NixOS modules are executable configuration: inspect and
trust them before evaluation. Arbitrary relative imports may require a dedicated
host module.

Local checks evaluate complete Intel/UEFI, AMD/BIOS and NVIDIA configurations and
test account/disk isolation. Bootstrap has been previewed on the reference
Lenovo; the complete fresh-install activation path still needs a VM or spare-PC
trial. These checks do not establish boot or graphics behavior on every PC.
