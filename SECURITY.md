# Security

## How Gautham's Clipboard was checked

Version 2.0 was reviewed with Cloudflare's
[security-audit skill](https://github.com/cloudflare/security-audit-skill)
(quick profile, source review, commit `8ab19b4`). It covered the clipboard monitor,
on-disk history and cleanup, paste and typing into other apps, caret lookup,
the in-place updater, the one-line installer and the release scripts.

**Result: no confirmed vulnerabilities.** The leads and hardening notes it raised
were fixed in the next commit:

| Lead | Fix |
|---|---|
| HTML copies used the system importer, which can load remote images | HTML is stripped to text locally; nothing is ever fetched |
| Updater could delete the app if its backup failed | It now stops and keeps the current version |
| Updater and installer accepted any bundle with the right ID | They also require an intact code signature |
| Copying the same image twice left an untracked file | Duplicates are detected before writing; stray files are swept |
| ⌘V could go to another app if focus never came back | The paste is skipped; the pick stays on the clipboard |
| One-time codes could stay up to an hour | Cleanup runs every 5 minutes |
| Debug flags (`--install-update`, `--dump`, `--selftest`) shipped in release builds | Compiled out of release builds |

## Known limit

Releases are not yet signed with an Apple Developer ID or notarized, so updates are
trusted because they come from this repository's GitHub releases (only the owner
can publish them). Signed and notarized releases are planned.

## Reporting a problem

Please open a private
[security advisory](https://github.com/GauthamWho/gs-clipboard/security/advisories/new)
or message [@gautamwho](https://instagram.com/gautamwho). Do not post details in a
public issue.
