# Issue tracker

I track issues and specifications in GitHub Issues for
`AldogPlays/nixos-config`. Use the `gh` CLI with that explicit repository.

Before publishing, verify the target with `gh repo view`.
When a skill says to publish to the issue tracker, create a GitHub issue.
Before creating an issue, check for existing issues covering the same work.

Use temporary body files and `--body-file` for multiline issue descriptions
and comments. Apply triage labels according to `triage-labels.md`.

Use native GitHub sub-issues and issue dependencies when supported.
Otherwise, record parent and blocker references in the issue body.

Pull requests are not a request surface for triage.
Publishing an issue does not authorize implementing it.
