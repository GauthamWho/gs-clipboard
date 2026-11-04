# Changelog

All notable changes to G's Clipboard are listed here.
This project follows [semantic versioning](https://semver.org).

## [1.0.1] — 2026-11-04

### Fixed
- **The panel now updates the moment you copy something.** Previously the list
  was drawn once at launch and could look frozen, so a freshly copied item
  seemed to be missing even though it had been saved.
- Opening the panel always clears any leftover search text and scrolls back to
  the newest item.
- Copying rich text from apps that provide only HTML or RTF is now saved
  correctly.

### Added
- A local-only diagnostic log at `~/Library/Logs/G's Clipboard.log` to make
  support questions easy to answer. It stays on your Mac.

## [1.0.0] — 2026-11-04

First public release.

### Added
- Unlimited clipboard history for text, images, and file paths.
- Windows+V-style popover opened with **⌥V** anywhere in macOS.
- Search, pin, delete, and clear.
- Automatic image thumbnails with a memory-safe cache.
- Menu-bar icon with a right-click menu (About, Updates, Settings, Quit).
- Launch at login, enabled automatically on first run.
- Automatic update check once a day, with one-click install.
- Completely local storage — no account, no cloud, no tracking.
- Blue-and-white app icon with the "G" monogram.
- One-line installer and a native macOS ARM + Intel build.
