# Maintenance and recovery

I keep my intended system state in this repository and `flake.lock`. A running
session can still belong to an earlier generation until changes are activated.

## Validate a checkout

I run these checks from the repository root:

```bash
git diff --check
nix fmt
nix flake check --show-trace
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

Formatting can be limited to changed Nix files with `nix fmt -- path/to/file.nix`.
Review the resulting diff. Git-backed flakes omit untracked files, so add new
configuration files to Git before evaluating them.

A dry run checks evaluation and planned builds. The final command builds the
complete reference generation without creating a `result` symlink. Flake checks
cover regressions and portable-host evaluation; they are not physical boot tests.
Validation runs locally; no GitHub Actions workflow is configured.

## Apply the configuration

On my Lenovo, I apply the checked-in host with:

```bash
sudo nixos-rebuild dry-activate --flake .#nixos
sudo nixos-rebuild switch --flake .#nixos
```

On a machine I set up through bootstrap, I use its generated host:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Home Manager is integrated into NixOS, so a separate `home-manager switch` is not
needed. Review service changes before switching. Activation is not a reboot, but
changed services can restart. Do not restart the display manager or compositor
just to preview styling in a working session.

The generated host's project source is pinned. Rerun bootstrap from an updated
project revision to adopt upstream project changes; see
[updating a generated host](installation.md#updating-a-generated-host).

## Update inputs

I update pinned inputs from the project checkout:

```bash
nix flake update
nix flake check --show-trace
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

Review `flake.lock` and package/module changes before activation. For a single
dependency, use a targeted update such as `nix flake update wiremix`. I keep
`system.stateVersion` and `home.stateVersion` unchanged during routine input
upgrades: they are compatibility baselines, not release selectors.

NixOS and Home Manager should have compatible branches. Native APIs, package
patches and the compositor plugin need review when their pinned versions change.

Instagram's separately signed Android clone has its own manual update workflow,
original-APK backups and private signing key. It is not updated by `nix flake
update` or a routine system switch. See the [Instagram package guide](../packages/instagram-reels/README.md).

## Security checks

I run security checks on demand from the checkout; they do not install a
resident scanner or update my pinned inputs. I scan Git history with redacted
findings:

```bash
nix shell --inputs-from . nixpkgs#gitleaks --command \
  gitleaks git --redact=100 --log-opts=--all .
```

I review the working diff separately because the history scan does not cover
uncommitted files. I also scan the current tree:

```bash
nix shell --inputs-from . nixpkgs#gitleaks --command \
  gitleaks dir --redact=100 .
```

I keep downloaded installers, signing keys, and credentials outside Git. My host
intentionally retains identifying metadata; removing it from the latest tree
would not remove it from existing history. I describe my [public-source
checks](public-release.md) separately.

When reviewing software updates, I can also scan the activated system:

```bash
nix shell --inputs-from . nixpkgs#vulnix --command vulnix --system
```

Vulnix downloads and caches vulnerability data on demand. Its package-name/version
matching is heuristic: review reported candidates against the pinned package's
patches and upstream advisories before changing configuration. Findings do not
trigger automatic upgrades or service restarts. A scan does not establish that
every dependency is safe. See the [upstream scanner](https://github.com/nix-community/vulnix).

Independent personal-data backups and restore testing remain separate from NixOS
generation rollback. Automatic idle locking and sleeping are not configured;
the existing manual controls remain in use.

## Recovery

I recover through an earlier boot-menu generation or roll back the running
system:

```bash
sudo nixos-rebuild switch --rollback
```

My host has no boot-menu countdown. Hold Space during firmware startup to open
the systemd-boot menu. If an old menu timeout persists after rebuilding, clear
its EFI override with `sudo bootctl set-timeout ''`. Other bootloaders keep
their own recovery controls.

Rollback selects an older system generation; it does not revert the Git checkout,
restore personal files or necessarily undo firmware settings. For normal full
charging before removing the conservation policy, use
`sudo battery-charge full`. Bring the source configuration back into agreement
with the chosen generation before rebuilding again.

Weekly garbage collection removes generations according to the declared retention
policy. Keep independent backups; retained generations are not a data backup.
Inspect `.hm-backup` files before removing them after Home Manager activation.

To collect only unreferenced Nix store paths while preserving existing profile
generations:

```bash
sudo nix-store --gc
```

This does not prune generations. The weekly retention policy remains separate;
pruning a generation removes that rollback choice and can make its unique store
paths collectible. Inspect project build caches and Git worktrees separately
before removing them, since they may contain active or uncommitted work. Disk
usage totals can count shared Btrfs extents more than once; use `df -h /` to
measure space actually recovered.

## Desktop memory safeguards

`modules/nixos/core.nix` declares bounded zswap caching for hosts with disk swap,
application-only systemd-oomd monitoring, and conservative Nix build concurrency.
These shared settings also apply to bootstrap-generated hosts. Zswap uses the
existing swap device and NixOS sysfs setters, without a new resident daemon.
Hosts without disk swap or using zram skip zswap.

The OOM policy can forcibly close a whole application unit and lose unsaved work.
It monitors `app.slice`; Hyprland's `session.slice` is outside that scope.
The memory-pressure percentage measures stalled time rather than RAM usage.
Zswap trades CPU work and some RAM for reduced disk swapping. Nix concurrency
limits reduce build contention, but cannot bound every build's memory use.

After activation, I check the live policy without inducing memory exhaustion:

```bash
oomctl --no-pager
systemctl --user show app.slice -p ManagedOOMMemoryPressure -p ManagedOOMSwap
cat /sys/module/zswap/parameters/enabled
cat /sys/module/zswap/parameters/max_pool_percent
nix config show | rg '^(max-jobs|cores) ='
```

Kernel parameters also preserve zswap settings on subsequent boots. Changing the
power-policy target fixes its boot ordering; a successful activation does not
establish that a fresh boot has been tested. No reboot is needed for the live
memory settings.

## Diagnostics

```bash
systemctl --failed
systemctl --user --failed
hyprctl configerrors
battery-charge status
```

I use service-specific journal output for focused diagnostics, for example
`journalctl -u battery-charge-limit.service -b` or `journalctl --user -u
waybar.service -b`. I review logs before sharing them: network names, addresses,
filenames and account details can appear in diagnostic output.
