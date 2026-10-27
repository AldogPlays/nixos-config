# Contributing

This is a personal NixOS configuration with a portable bootstrap path. Changes
should stay small, reproducible and consistent with the existing modules.

## Bug reports

Include the project revision (`git rev-parse HEAD`), NixOS version
(`nixos-version`), relevant hardware, reproduction steps and expected behavior.
State whether the configuration was activated: a checkout and the running system
can differ. For bootstrap issues, identify preview versus apply and describe the
existing bootloader and layout without posting private configuration files.

Trim logs to the relevant service and remove tokens, personal paths and network
details. Use the [security policy](SECURITY.md) for sensitive reports.

## Changes

- Prefer the existing component module over a new abstraction for a small change.
- Keep packages and persistent settings declarative and compatible with pinned
  inputs. Keep machine-specific disks, accounts and boot settings in host files.
- Preserve compatibility baselines, encryption and mount topology unless the
  change explicitly concerns them.
- Keep shared styling in the [theme contract](theme/README.md), and explain any
  new service, dependency or hardware requirement.
- Write documentation for readers: describe behavior, setup and limitations
  directly, without conversation history or task narration.
- Update the relevant guide when commands or behavior change.

Run the checks in [maintenance](docs/maintenance.md#validate-a-checkout). Build
the complete generation for system changes when practical. Describe what was
checked and distinguish evaluation, full builds and physical hardware tests.
Include reproduction steps or focused regression coverage for behavioral fixes.

Keep pull requests focused. Explain the problem, resulting behavior and relevant
validation. Keep private hardware files, credentials, downloaded installers,
wallpapers and runtime caches out of patches. Contributions retain applicable
third-party notices; see [licensing](THIRD_PARTY_NOTICES.md).
