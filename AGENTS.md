# Agent guide

This file gives agents working direction. Keep system inventory, configuration
values, decisions, progress notes, and completed work out of this file.

## Owner's direction

- Build a clean, slim, reproducible NixOS and Hyprland setup managed through Git
  and GitHub, customized to Jeffrey's specifications.
- Jeffrey wants control over each part of the desktop. Explain which component
  provides a feature, where its configuration lives, and how it starts. Make
  additions, replacements, and new background services explicit in the proposed
  change; avoid installing a desktop bundle for one small feature.
- Implement requested customization with the smallest practical change. Existing
  bootstrap defaults are a starting point, not proof of personal preference.
  Do not add features, dependencies, or visual effects just because they are
  common in other Hyprland setups.
- Prefer compact spacing, thin borders, and restrained decoration.
- Keep persistent customization in this repository so it survives rebuilds and
  can be reproduced from the pinned inputs. Explain what was applied live and
  what still requires activation.
- Respect documented decisions and pending choices. Read `docs/system-context.md`
  and relevant component documentation before changing their behavior.

## Start here

- Read `README.md`, `docs/system-context.md`, and the modules relevant to the task.
- Check `git status --short --branch` and the existing diff before editing.
  Preserve unrelated user changes.
- Treat the checked-in configuration and `flake.lock` as the source for intended
  state. Inspect the running system separately when runtime behavior matters;
  repository changes may not have been activated yet.
- `docs/audit.md` is a dated bootstrap record, including observations from before
  migration. Recheck its claims before treating them as current facts.
- For a review or diagnosis, inspect and report findings. For an implementation
  request, make the change and perform relevant checks. Resolve routine choices
  independently; ask when a missing preference materially changes the outcome.

## Implementation rules

Prefer the existing modules over adding new abstractions for small changes.
Declare persistent settings and packages here rather than editing generated
files, `/nix/store`, `/etc/nixos`, or installing into an imperative user profile.
Temporary diagnostic changes should be identified and either removed or made
declarative as appropriate.

- Preserve `system.stateVersion` and `home.stateVersion` during input upgrades.
  They are compatibility baselines, not release selectors.
- Consider the hardware when proposing kernel changes. Verify driver support and
  explain the reason for a change.
- Preserve disk UUIDs, mount topology, and encryption unless the task specifically
  involves changing them. Storage migrations require a recovery plan and user
  authorization for destructive steps.
- Follow the existing configuration format and the pinned version's API rather
  than copying examples from other releases. Declare commands used by new
  keybindings through the appropriate package or service module.
- Use the existing session service mechanism consistently; avoid starting
  duplicate background processes from compositor configuration.
- NixOS modules can supply implicit configuration. Inspect the pinned module or
  evaluated options before calling something missing.
- Inspect Home Manager file collisions and preserve user content instead of
  deleting backups to force activation.
- Account for generation retention when planning recovery; NixOS rollback does
  not restore personal data or replace a backup.
- Check repository visibility and remote settings directly when relevant;
  a Git remote URL alone does not establish them.
- Keep credentials and private keys out of this repository and Nix expressions
  that copy them into the store. Use an appropriate secret mechanism when needed.

## Validation and activation

From the repository root, use checks appropriate to the change:

```bash
git diff --check
nix fmt
nix flake check --show-trace
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --dry-run
```

Formatting should cover the files changed for the task; inspect and avoid
unrelated formatting churn. A dry run checks evaluation and planned builds; it
does not prove that the complete system builds. For system changes, build the
generation when practical:

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

Git-backed flakes omit new files until Git tracks them. Account for this when
adding modules; do not misdiagnose an omitted file as a Nix configuration error.
Use the repository formatter and pinned options instead of hand-editing the lock
file or broadly updating inputs to make an unrelated change work.

When the user requests applying the configuration, activate the verified result:

```bash
sudo nixos-rebuild switch --flake .#nixos
```

Activation can affect running services. Match it to the user's request; editing
documentation does not require activation. Rebooting, logging out, and restarting
the compositor disrupt the session and need explicit intent from the user.
Rollback is available through the boot menu or:

```bash
sudo nixos-rebuild switch --rollback
```

For runtime issues, use focused diagnostics such as `systemctl --failed`,
`systemctl --user --failed`, relevant `journalctl` output, `hyprctl`, and `wpctl`.
Recheck the affected behavior after activation when access permits.

Agent environments may restrict the Nix daemon, D-Bus, compositor, device nodes,
or caches. Treat permission/socket failures as diagnostic limitations, not proof
of broken services. Use the supported approval mechanism for necessary host
access. Clearly report checks that could not run; syntax parsing alone is not a
successful flake evaluation, build, or runtime check.

## Handoff and upkeep

- Explain what changed, why, what was checked, and any remaining limitation.
- After making repository changes, ask Jeffrey whether to commit and push them
  to GitHub, unless he has already requested a push for that work. Do not push
  automatically without that authorization.
- Commit, push, publish, or change remote settings when the user requests those
  actions; preserve the existing Git history and unrelated changes.
- Change this guide when the directions for agents change. Do not append task
  results, configuration values, inventories, or decision history here.
- Keep current system context and consequential decisions with their rationale in
  `docs/system-context.md` or the relevant component documentation. Avoid
  duplicating settings already expressed clearly in Nix. Git history records
  completed changes; do not create a running agent activity log.
- Update `README.md` when setup or maintenance commands change. Keep dated audit
  observations clearly historical; record confirmed later findings with a date.
- Report possible improvements as proposals unless they are part of the current
  task. A future agent should be able to distinguish configured behavior from
  intended work and unverified ideas.
