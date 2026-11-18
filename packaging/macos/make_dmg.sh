#!/usr/bin/env bash
# macOS disk image (task 5.6). Run on a Mac after `flutter build macos
# --release`:
#   packaging/macos/make_dmg.sh 1.0.0
#
# Signing and notarisation happen only when these are set (CI secrets):
#   MACOS_SIGN_IDENTITY   "Developer ID Application: Name (TEAMID)"
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD   for notarytool
# Without them the DMG is unsigned: Gatekeeper asks users to right-click >
# Open the first time.
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION=${1:?version}
APP=build/macos/Build/Products/Release/kyndrel.app
OUT=build/installer
DMG="$OUT/Kyndrel-$VERSION-macos-universal.dmg"
[ -d "$APP" ] || { echo "missing $APP; run flutter build macos --release" >&2; exit 1; }
mkdir -p "$OUT"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Kyndrel.app"
ln -s /Applications "$STAGE/Applications"

if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  # Sign nested frameworks/dylibs first, then the app, with the hardened
  # runtime that notarisation requires.
  find "$STAGE/Kyndrel.app/Contents" \( -name '*.dylib' -o -name '*.framework' \) \
    -print0 | xargs -0 -I{} codesign --force --timestamp --options runtime \
    --sign "$MACOS_SIGN_IDENTITY" {}
  codesign --force --timestamp --options runtime \
    --entitlements macos/Runner/Release.entitlements \
    --sign "$MACOS_SIGN_IDENTITY" "$STAGE/Kyndrel.app"
  codesign --verify --deep --strict "$STAGE/Kyndrel.app"
fi

rm -f "$DMG"
hdiutil create -volname "Kyndrel $VERSION" -srcfolder "$STAGE" -ov \
  -format UDZO "$DMG"

if [ -n "${MACOS_SIGN_IDENTITY:-}" ]; then
  codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$DMG"
fi
if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
  xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
  xcrun stapler staple "$DMG"
fi
echo "$DMG"
