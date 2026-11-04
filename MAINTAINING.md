# Maintaining G's Clipboard

Notes for the owner (Gautam). Everything here is optional reading for users.

## One-time GitHub setup

The repo lives at **https://github.com/GauthamWho/gs-clipboard**.

```bash
brew install gh          # GitHub CLI
gh auth login            # choose GitHub.com → HTTPS → login with a browser
```

Then create the repo and push the first commit:

```bash
cd ~/Projects/gs-clipboard
git init -b main
git add -A
git commit -m "G's Clipboard 1.0.0"
gh repo create GauthamWho/gs-clipboard --public --source=. --push \
  --description "A free, local clipboard manager for macOS with a Windows+V-style panel."
gh repo edit GauthamWho/gs-clipboard \
  --add-topic macos,clipboard,clipboard-manager,swift,swiftui,productivity,privacy
```

Turn on Issues so people can ask for features:

```bash
gh repo edit GauthamWho/gs-clipboard --enable-issues
```

## Publishing an update

1. Bump the version in `CHANGELOG.md` (add a new section).
2. Commit and push:

```bash
git add -A
git commit -m "G's Clipboard 1.0.1"
git push
```

3. Build a universal app and publish it:

```bash
./release.sh 1.0.1
```

This builds the app for **Apple Silicon and Intel**, packages
`GsClipboard.app.zip`, and creates the GitHub release. The one-line installer
and the in-app updater both pick it up automatically.

Within a day, every installed copy shows **“Update 1.0.1”**. One click installs
it. Nobody downloads anything manually.

### How users get it

- The app calls
  `https://api.github.com/repos/GauthamWho/gs-clipboard/releases/latest` once a
  day (no personal data).
- If the tag is newer than the installed version, an update button appears.

## Testing a release locally

```bash
./build.sh
open "build/G's Clipboard.app"
```

Test text capture, image capture, ⌥V, search, pin, and the About/Settings
windows.

To test the updater without publishing:

```bash
VERSION=1.0.1 ./build.sh
ditto -c -k --keepParent "build/G's Clipboard.app" /tmp/test.zip
GS_UPDATE_DEST="/tmp/test-install/G's Clipboard.app" \
  "/Applications/G's Clipboard.app/Contents/MacOS/GsClipboard" \
  --install-update /tmp/test.zip
```

## What users can and cannot see

- Everything is local. There is no analytics, no crash reporting, no account.
- The only server contact is the daily release check.
- Clipboard history lives in
  `~/Library/Application Support/G's Clipboard/`.
- The app does not request Accessibility, Screen Recording, or Full Disk
  Access.

## Code signing (optional)

The app is **ad-hoc signed**, which is free. The installer removes the macOS
quarantine flag, so it opens normally.

If you ever join the Apple Developer Program (99 USD/year), you can sign with a
Developer ID and notarize the app. Then even browser downloads open without a
warning. Publish the notarized app with the same `GsClipboard.app.zip` asset name
and the updater keeps working unchanged.

## Optional: GitHub Actions

Releases are currently built on your Mac by `release.sh`. If you later want
GitHub to build them in the cloud, you need one extra permission once:

```bash
gh auth refresh -h github.com -s workflow
```

Then add back a workflow that runs `UNIVERSAL=1 ./build.sh` and uploads
`GsClipboard.app.zip` to the release. Until then, no workflow scope is needed.

## Social preview

GitHub lets you set a repository image in **Settings → Social preview**. Use
`Resources/AppIcon-1024.png`.

## Files to edit for branding

| What | Where |
|---|---|
| App name, version, copyright | `build.sh` (Info.plist section) |
| Icon | `tools/make-icon.swift` then run `swift tools/make-icon.swift` |
| GitHub/Instagram links | `README.md`, `AboutView.swift`, `SettingsView.swift`, `PRIVACY.md`, `LICENSE` |
| Update repo | `UpdateChecker.swift` (`repoOwner`, `repoName`) |
| Installer | `install.sh` |

## Support checklist

When someone reports a problem:

1. Ask for macOS version and whether ⌥V or the menu-bar icon fails.
2. Check **Settings → Updates** for the installed version.
3. If the app will not open, ask them to run:

   ```bash
   xattr -dr com.apple.quarantine "/Applications/G's Clipboard.app"
   ```

4. If their history is gone, check
   `~/Library/Application Support/G's Clipboard/`.
5. If a copy "did not appear", open `~/Library/Logs/G's Clipboard.log`. Every
   capture is logged as `captured text change=… len=…` and every panel update as
   `panel refreshed … -> … items`. If the capture line is there but the refresh
   line is missing, the panel is not updating — that was the 1.0.0 bug, fixed in
   1.0.1.
6. Make sure the user is not also running another clipboard manager, since two
   apps can claim the same shortcut.
