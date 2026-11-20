# Security

I maintain the current `main` branch and its pinned inputs. I do not maintain
separate release branches.

## Reporting a vulnerability

I prefer private vulnerability reports through **Report a vulnerability** in
GitHub's Security tab when that option is available. Otherwise, I ask for an
issue requesting a private contact method, without vulnerability details,
credentials, or an exploit. I appreciate a private discussion before disclosure.

For ordinary configuration bugs, I use the bug-report template.

## Sensitive information

I keep passwords, private keys, access tokens, recovery material, application
accounts, and personal configuration exports outside Git. I review logs,
screenshots, and generated host files before sharing them.

My checked-in host includes my login name, hardware model, disk identifiers, and
storage layout. My Git author identity is part of the history. These describe my
installation; they are not portable defaults or encryption keys. Bootstrap uses
the destination machine's hardware configuration instead.

My homelab CA file is a public certificate. Its private key and my WireGuard
credentials are stored separately. I describe this boundary in my [public-source
checks](docs/public-release.md).

I treat Nix expressions and modules as executable configuration and inspect
sources before evaluation or activation. I do not use the Nix store for secrets
or put credentials in expressions that copy them into store paths.
