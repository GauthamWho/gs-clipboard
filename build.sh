#!/bin/bash
# Builds "Gautham's Clipboard.app" from source.
#
#   ./build.sh                 # fast local build (your Mac's architecture)
#   UNIVERSAL=1 ./build.sh     # Apple Silicon + Intel (used for releases)
#   VERSION=1.2.0 BUILD_NUMBER=12 ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Gautham's Clipboard"
EXECUTABLE="GsClipboard"
VERSION="${VERSION:-2.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER)..."

if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
else
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/$EXECUTABLE"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>com.gautham.gsclipboard</string>
    <key>CFBundleExecutable</key><string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 GauthamWho. All rights reserved.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# A stable signing identity keeps the Accessibility permission across rebuilds
# (ad-hoc signatures change every build, so macOS forgets the permission).
SIGN_ID="${SIGN_ID:-$(security find-identity -p codesigning -v 2>/dev/null | awk '/Apple Development|Developer ID Application/ {print $2; exit}')}"
SIGN_ID="${SIGN_ID:--}"
echo "==> Signing ($SIGN_ID)..."
codesign --force --deep --sign "$SIGN_ID" "$APP"

echo "==> Built: $APP"
