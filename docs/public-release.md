# Publishing the repository

Repository visibility is a separate GitHub setting. Preparing or pushing the
configuration does not make it public.

## Review before publishing

- Validate the exact revision using the [maintenance checks](maintenance.md).
  Try bootstrap on a fresh VM or spare PC before describing installation as
  deployment-tested. Check graphical unlocking and the battery cutoff on hardware.
- Confirm that every pinned source is publicly accessible, including forks.
  Proprietary installers and application sign-ins remain separate prerequisites.
- Review the current tree, Git history and any GitHub Actions logs or artifacts
  for credentials and private data. Local secret scans are useful but are not a
  guarantee that every sensitive value has been identified.
- Keep the [MIT license](../LICENSE) and [third-party notices](../THIRD_PARTY_NOTICES.md)
  with the source. Packaged software keeps its own distribution terms.
- Review issue templates, contribution guidance and the private vulnerability
  reporting route in GitHub's Security settings.
- Confirm local commits are pushed and the default branch matches the intended
  release revision. Public-facing documentation should describe behavior and
  limitations directly, without conversation history.

The reference host intentionally retains its account name, disk identifiers and
storage layout. Existing author attribution and Git history are retained too.
Removing information from the latest files does not remove it from earlier
commits. Do not publish the checked-in host as a portable hardware template.

## Change visibility when ready

Open the repository's **Settings → General → Danger Zone → Change repository
visibility**. Review GitHub's confirmation and consequences before choosing
public visibility. See [GitHub's visibility documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility).

Once public, test the README's GitHub bootstrap reference without private
repository credentials. Check the repository's community profile, license
detection, issue templates and Security reporting options from a reader's account.
Public copies and forks can remain available even if visibility changes later.
