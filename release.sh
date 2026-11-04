#!/bin/bash
# Builds a universal macOS app and publishes it as a GitHub Release.
#
#   ./release.sh 1.0.1
#
# Once published, every installed copy shows "Update 1.0.1" within a day,
# and users install it with one click.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh <version>    e.g. ./release.sh 1.0.1"
    exit 1
fi
VERSION="${VERSION#v}"

if [ -n "$(git status --porcelain)" ]; then
    echo "There are uncommitted changes. Commit and push them first."
    exit 1
fi

echo "==> Building Gautham's Clipboard $VERSION (Apple Silicon + Intel)..."
SIGN_ID=- VERSION="$VERSION" BUILD_NUMBER="$(date +%Y%m%d%H%M)" UNIVERSAL=1 ./build.sh

ZIP="GsClipboard.app.zip"
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --keepParent "build/Gautham's Clipboard.app" "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"

if gh release view "v$VERSION" >/dev/null 2>&1; then
    echo "==> Release v$VERSION already exists; replacing its build..."
    gh release upload "v$VERSION" "$ZIP" "$ZIP.sha256" --clobber
else
    echo "==> Publishing release v$VERSION..."
    gh release create "v$VERSION" "$ZIP" "$ZIP.sha256" \
        --title "Gautham's Clipboard $VERSION" \
        --notes "See CHANGELOG.md for what's new in $VERSION." \
        --latest
fi

rm -f "$ZIP" "$ZIP.sha256"

echo "✅ Published: https://github.com/GauthamWho/gs-clipboard/releases/tag/v$VERSION"
echo "   The one-line installer now serves this version."
