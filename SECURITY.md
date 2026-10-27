# Security

Security maintenance targets the current `main` branch and its pinned inputs.
There are no separately maintained release branches.

## Reporting a vulnerability

Use **Report a vulnerability** in the repository's Security tab when private
reporting is available. If that option is unavailable, open an issue requesting
a private contact method without including vulnerability details, credentials
or an exploit. Please allow a private discussion before public disclosure.

For ordinary configuration bugs, use the bug-report template.

## Sensitive information

Do not submit passwords, private keys, access tokens, Tailscale authentication
keys, recovery material or complete personal configuration directories.
Review logs, screenshots and generated host files before attaching them.

The reference host intentionally includes a login name, hardware model, disk
identifiers and storage layout. These identify this installation; they are not
portable defaults or encryption keys. Bootstrap uses the destination machine's
hardware configuration instead. Git history and attribution are retained.

Nix expressions and NixOS modules are executable configuration. Inspect sources
before evaluation or activation. The Nix store is not a secret store: do not
place credentials in expressions that copy them into store paths.
