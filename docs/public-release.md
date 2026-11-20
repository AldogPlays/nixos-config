# Public-source checks

I share this repository as my personal desktop configuration. My checked-in host
reflects my hardware and preferences; bootstrap is how I reproduce the shared
parts on another installed NixOS machine.

## What I check before pushing

- I review the diff and run the relevant [maintenance checks](maintenance.md).
- I scan the current tree and Git history for credentials, private keys, and
  accidentally committed local files. I use redacted scanner output and review
  findings manually; a clean scan is not proof that every sensitive value is absent.
- I keep account data, private keys, original APKs, installers, and personal
  wallpaper collections outside Git and the Nix store.
- I check that pinned sources, including my forks, can be fetched publicly.
- I retain the [MIT license](../LICENSE) and [third-party notices](../THIRD_PARTY_NOTICES.md).
- I check links and write documentation in my own voice, with clear limits on
  what I have actually tested.
- I verify that the pushed branch matches the intended local commit.

## Information I keep public

My host includes my account name, hardware model, disk identifiers, monitor
configuration, and storage layout. My Git author name and email are also part of
the history. My homelab notes describe private subnets and local service names.
These are configuration details, not account passwords or encryption keys.

I include my homelab's public Caddy CA certificate so my laptop can trust its
services. The CA private key and WireGuard credentials stay outside this
repository. Bootstrap does not inherit my laptop's CA trust or VPN
configuration.

Deleting something from the latest files would not remove earlier commits. If I
discover an exposed credential, I revoke or rotate it before considering history
cleanup. Public copies and forks may remain available independently of this
repository's visibility. I keep [GitHub's visibility
documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)
as a reference for those consequences.

## Scope of my checks

I use this setup on my Lenovo and run local regression checks. I have not
completed a fresh VM or spare-PC bootstrap activation trial, so I keep that
limitation in the installation guide. I do not present my personal configuration
as a generally supported distribution.

I also review GitHub issues, releases, workflow logs, and artifacts when sharing
project material. My [security policy](../SECURITY.md) describes how I handle
sensitive reports.
