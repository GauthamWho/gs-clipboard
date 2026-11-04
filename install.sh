#!/bin/bash
# Gautham's Clipboard — one-line installer for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/GauthamWho/gs-clipboard/main/install.sh | bash
#
# Downloads the latest release, installs it to /Applications, removes the macOS
# quarantine flag, and opens the app.
set -euo pipefail

REPO="GauthamWho/gs-clipboard"
APP_NAME="Gautham's Clipboard"
APP="$APP_NAME.app"
DEST="/Applications/$APP"
ZIP_URL="https://github.com/$REPO/releases/latest/download/GsClipboard.app.zip"
PAGE_URL="https://github.com/$REPO"

blue()  { printf "\033[38;5;33m%s\033[0m\n" "$1"; }
green() { printf "\033[38;5;35m%s\033[0m\n" "$1"; }
red()   { printf "\033[38;5;196m%s\033[0m\n" "$1"; }

blue "┌──────────────────────────────────────────────┐"
blue "│            Gautham's Clipboard  ·  installer       │"
blue "└──────────────────────────────────────────────┘"
echo

if [ "$(uname -s)" != "Darwin" ]; then
    red "This installer is for macOS only."
    exit 1
fi

MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MACOS_MAJOR" -lt 14 ]; then
    red "Gautham's Clipboard needs macOS 14 (Sonoma) or newer. You have $(sw_vers -productVersion)."
    exit 1
fi

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

echo "→ Downloading the latest version…"
if ! curl -fL --progress-bar "$ZIP_URL" -o "$TMP/app.zip"; then
    echo
    red "Could not download Gautham's Clipboard."
    red "There may be no release published yet, or the network is blocked."
    red "Open $PAGE_URL/releases and download the ZIP manually."
    exit 1
fi

echo
echo "→ Unpacking…"
ditto -x -k "$TMP/app.zip" "$TMP/unpack"

SRC="$TMP/unpack/$APP"
# Older releases ship the app under its earlier name; accept whichever app is inside.
[ -d "$SRC" ] || SRC="$(find "$TMP/unpack" -maxdepth 1 -name '*.app' | head -1)"
BID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SRC/Contents/Info.plist" 2>/dev/null || true)"
if [ ! -d "$SRC" ] || [ "$BID" != "com.gautham.gsclipboard" ] || ! codesign --verify --deep --strict "$SRC" 2>/dev/null; then
    red "The download did not contain $APP."
    exit 1
fi

# The download came from curl, but strip the quarantine flag just in case.
xattr -dr com.apple.quarantine "$SRC" 2>/dev/null || true

echo "→ Quitting any running copy…"
osascript -e 'tell application id "com.gautham.gsclipboard" to quit' 2>/dev/null || true
pkill -f "$APP/Contents/MacOS/GsClipboard" 2>/dev/null || true
sleep 1

echo "→ Installing to /Applications…"
if [ -w /Applications ]; then
    rm -rf "$DEST"
    cp -R "$SRC" "$DEST"
    xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
else
    echo "  (your account needs permission — enter your Mac password)"
    sudo rm -rf "$DEST"
    sudo cp -R "$SRC" "$DEST"
    sudo xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
fi

echo "→ Starting Gautham's Clipboard…"
open "$DEST"

echo
green "✅ Installed. Gautham's Clipboard is now in your menu bar."
echo "   Look for the clipboard icon at the top-right of your screen."
echo "   Press ⌥V (Option + V) anywhere to open your history."
echo
echo "   History is stored only on this Mac:"
echo "   ~/Library/Application Support/Gautham's Clipboard/"
echo
echo "   Made by GauthamWho · instagram.com/gautamwho"
