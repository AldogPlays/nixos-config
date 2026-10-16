# NixOS configuration

Flake-based NixOS and Home Manager configuration for the `nixos` host (Lenovo IdeaPad 5 2-in-1 14AKP10) and user `jeffreyc`.

## Layout

```text
flake.nix                     pinned inputs and host output
hosts/nixos/                  machine identity, disks, and boot hardware
modules/nixos/                reusable OS, hardware, and desktop modules
home/jeffreyc/                Home Manager modules
dotfiles/hypr/                versioned Hyprland configuration
docs/audit.md                 bootstrap hardware/configuration audit
```

## First activation

Review the diff and evaluate before switching:

```bash
nix flake check --show-trace
sudo nixos-rebuild dry-build --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

Home Manager is integrated into the NixOS configuration; a separate `home-manager switch` is not required.

The first activation may preserve a conflicting user file with the suffix `.hm-backup`. After confirming the managed version, remove the backup manually.

## Routine maintenance

```bash
nix flake update
nix flake check
sudo nixos-rebuild switch --flake .#nixos
git add flake.lock
git commit -m "chore: update flake inputs"
```

Roll back from the boot menu or with `sudo nixos-rebuild switch --rollback` if a generation misbehaves.

## GitHub setup

Authenticate and create a private repository when ready:

```bash
gh auth login
gh repo create nixos-config --private --source=. --remote=origin --push
```

Change `--private` only if every tracked file has been reviewed for host-specific or sensitive information. Disk UUIDs are identifiers rather than encryption secrets, but this repository intentionally documents the machine model and storage layout.
