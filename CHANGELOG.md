# Changelog

All notable changes to Gautham's Clipboard are listed here.
This project follows [semantic versioning](https://semver.org).

## [2.0.0] — 2026-11-05

### New
- **Renamed to Gautham's Clipboard**, with a new logo: the two-sheet copy shape,
  a blue G sheet in front of a white sheet. History from G's Clipboard moves over.
- **Pastes where you clicked.** Pick an item and it is typed into the field you
  were in (needs Accessibility once; otherwise it is copied as before).
- **Opens next to your text cursor**, just under the line you type in (above it
  when there's no room), so it never covers your work. From the menu bar icon it
  drops under the icon.
- **Emoji tab (⌘E):** Apple's full emoji set in keyboard order, searchable, typed
  straight in without touching the clipboard.
- **Smart storage:** unused screenshots go after 10 days and text after 45 (reuse
  extends it, pins stay), one-time codes after 20 minutes, password-manager
  copies are never saved, old screenshots shrink to HEIC, 1.5 GB image ceiling.
  The history folder is kept out of Time Machine and Spotlight.
- **Real image thumbnails** in the list, and a **large preview** beside the
  panel when you hover or arrow onto an image.
- New look: native Liquid Glass on macOS 26 (system material on 14–15), a light
  that follows the pointer, a sliding selection, a readable candy-pink accent,
  filters (All, Text, Images, Files, Pinned, Emoji).
- Mac-standard keys: ↑↓, ↩ paste, ⌥↩ copy only, ⌘1–9, ⌘C copy, ⌘P pin,
  ⌘⌫ delete, ⌘E emoji, Tab switches filter, Home/End/Page keys, ⌘W and ⎋ close.

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
- A local-only diagnostic log at `~/Library/Logs/Gautham's Clipboard.log` to make
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
