# Contributing

I maintain this repository for my own NixOS desktop and share it for reference.
My defaults reflect my hardware and preferences. I welcome focused bug reports
and useful fixes, but I keep the scope centered on the setup I use.

I keep my coding-assistant instructions in [AGENTS.md](AGENTS.md), including my
rules for validation, activation, Git, and documentation.

## Bug reports

To investigate a bug, I need the project revision (`git rev-parse HEAD`), NixOS
version (`nixos-version`), relevant hardware, reproduction steps, and expected
behavior. I also need to know whether the configuration was activated: a
checkout and a running system can differ. For bootstrap problems, the
preview/apply mode and existing bootloader and storage layout help me reproduce
the issue.

I ask that reports include only relevant logs, with credentials, personal paths,
and network details removed. I describe sensitive reporting in my [security
policy](SECURITY.md).

## Changes

- I prefer small changes in the existing modules over new abstractions.
- I keep packages and settings declarative and compatible with pinned inputs.
- I keep machine-specific disks, accounts, and boot settings in host files.
- I preserve compatibility baselines, encryption, and mount topology during routine updates.
- I keep shared styling in the [theme contract](theme/README.md) and document new services or dependencies.
- I write documentation in my voice, explaining the configuration and its limits.
- I update the relevant guide when commands or behavior change.

I use the checks in [maintenance](docs/maintenance.md#validate-a-checkout) and
build the complete generation for system changes when practical. In change
descriptions, I distinguish evaluation, full builds, and physical hardware
tests. I look for focused regression coverage where behavior needs it.

I keep credentials, private hardware exports, downloaded installers, wallpapers,
and runtime caches out of patches. Contributions retain applicable third-party
notices; I describe those in [licensing](THIRD_PARTY_NOTICES.md).
