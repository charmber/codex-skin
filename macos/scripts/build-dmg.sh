#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
APP_SOURCE="$ROOT/app"
VERSION="$(/usr/bin/tr -d '[:space:]' < "$ROOT/VERSION")"
BUILD_NUMBER="${BUILD_NUMBER:-${VERSION//./}}"
RELEASE_DIR="$ROOT/release"
APP_NAME="Codex Dream Skin"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
DMG_PATH="$RELEASE_DIR/Codex-Dream-Skin-v$VERSION.dmg"
TMP="$(/usr/bin/mktemp -d /tmp/codex-dream-skin-dmg.XXXXXX)"
BUILD_ROOT="$TMP/build"
DMG_ROOT="$TMP/dmg"
SKIP_TESTS="false"
NOTARIZE="false"
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

cleanup() {
  /bin/rm -rf "$TMP"
}
trap cleanup EXIT

usage() {
  /usr/bin/printf '%s\n' \
    'Usage: build-dmg.sh [--skip-tests] [--unsigned] [--identity IDENTITY] [--notarize]' \
    '' \
    'Environment for notarization:' \
    '  NOTARY_KEYCHAIN_PROFILE' \
    '  or APPLE_API_KEY_PATH, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-tests) SKIP_TESTS="true"; shift ;;
    --unsigned) SIGN_IDENTITY="-"; shift ;;
    --identity) SIGN_IDENTITY="${2:-}"; shift 2 ;;
    --notarize) NOTARIZE="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *) /usr/bin/printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -n "$VERSION" ] || { /usr/bin/printf 'VERSION is empty.\n' >&2; exit 1; }
[ -f "$APP_SOURCE/Package.swift" ] || { /usr/bin/printf 'Swift package is missing.\n' >&2; exit 1; }
command -v swift >/dev/null 2>&1 || { /usr/bin/printf 'Swift is required. Install Xcode first.\n' >&2; exit 1; }
command -v xcrun >/dev/null 2>&1 || { /usr/bin/printf 'xcrun is required. Install Xcode first.\n' >&2; exit 1; }

if [ "$NOTARIZE" = "true" ] && [ "$SIGN_IDENTITY" = "-" ]; then
  /usr/bin/printf 'Notarization requires a Developer ID Application identity.\n' >&2
  exit 1
fi

if [ "$SKIP_TESTS" = "false" ]; then
  "$ROOT/tests/run-tests.sh"
fi

/bin/mkdir -p "$BUILD_ROOT" "$RELEASE_DIR"

build_architecture() {
  local arch="$1"
  local triple="${arch}-apple-macosx13.0"
  local scratch="$BUILD_ROOT/swift-$arch"
  /usr/bin/printf 'Building %s...\n' "$arch"
  swift build \
    --package-path "$APP_SOURCE" \
    --configuration release \
    --triple "$triple" \
    --scratch-path "$scratch" \
    --disable-sandbox
  swift build \
    --package-path "$APP_SOURCE" \
    --configuration release \
    --triple "$triple" \
    --scratch-path "$scratch" \
    --show-bin-path
}

ARM_BIN_DIR="$(build_architecture arm64 | /usr/bin/tail -n 1)"
INTEL_BIN_DIR="$(build_architecture x86_64 | /usr/bin/tail -n 1)"
ARM_BINARY="$ARM_BIN_DIR/CodexDreamSkinMenuBar"
INTEL_BINARY="$INTEL_BIN_DIR/CodexDreamSkinMenuBar"
[ -x "$ARM_BINARY" ] || { /usr/bin/printf 'arm64 binary missing: %s\n' "$ARM_BINARY" >&2; exit 1; }
[ -x "$INTEL_BINARY" ] || { /usr/bin/printf 'x86_64 binary missing: %s\n' "$INTEL_BINARY" >&2; exit 1; }

/bin/rm -rf "$APP_BUNDLE"
/bin/mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/Engine"
/usr/bin/lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$APP_BUNDLE/Contents/MacOS/CodexDreamSkinMenuBar"
/bin/chmod 755 "$APP_BUNDLE/Contents/MacOS/CodexDreamSkinMenuBar"

/usr/bin/sed \
  -e "s/__VERSION__/$VERSION/g" \
  -e "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" \
  "$APP_SOURCE/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"
/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

ICONSET="$TMP/AppIcon.iconset"
/usr/bin/xcrun swift "$APP_SOURCE/Tools/GenerateAppIcon.swift" "$ICONSET"
/usr/bin/iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

for directory in layouts palettes renderer schemas scripts themes; do
  /usr/bin/rsync -a "$ROOT/$directory/" "$APP_BUNDLE/Contents/Resources/Engine/$directory/"
done
for file in VERSION LICENSE NOTICE.md README.md THEME_PACKAGE.md package.json; do
  [ -f "$ROOT/$file" ] && /bin/cp "$ROOT/$file" "$APP_BUNDLE/Contents/Resources/Engine/$file"
done
/bin/chmod 700 "$APP_BUNDLE/Contents/Resources/Engine/scripts/"*.sh
/bin/chmod 600 "$APP_BUNDLE/Contents/Resources/Engine/scripts/"*.mjs \
  "$APP_BUNDLE/Contents/Resources/Engine/scripts/"*.js 2>/dev/null || true
/usr/bin/xattr -cr "$APP_BUNDLE"

if [ "$SIGN_IDENTITY" = "-" ]; then
  /usr/bin/codesign --force --sign - "$APP_BUNDLE"
else
  /usr/bin/codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/lipo "$APP_BUNDLE/Contents/MacOS/CodexDreamSkinMenuBar" -verify_arch arm64 x86_64

/bin/mkdir -p "$DMG_ROOT"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
/bin/ln -s /Applications "$DMG_ROOT/Applications"
/bin/rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH" >/dev/null

if [ "$SIGN_IDENTITY" != "-" ]; then
  /usr/bin/codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
  /usr/bin/codesign --verify --verbose=2 "$DMG_PATH"
fi

if [ "$NOTARIZE" = "true" ]; then
  if [ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
      --wait
  elif [ -n "${APPLE_API_KEY_PATH:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER_ID:-}" ]; then
    /usr/bin/xcrun notarytool submit "$DMG_PATH" \
      --key "$APPLE_API_KEY_PATH" \
      --key-id "$APPLE_API_KEY_ID" \
      --issuer "$APPLE_API_ISSUER_ID" \
      --wait
  else
    /usr/bin/printf 'Notarization credentials are missing.\n' >&2
    exit 1
  fi
  /usr/bin/xcrun stapler staple "$DMG_PATH"
  /usr/bin/xcrun stapler validate "$DMG_PATH"
fi

SHA256="$(/usr/bin/shasum -a 256 "$DMG_PATH" | /usr/bin/awk '{print $1}')"
/usr/bin/printf '%s  %s\n' "$SHA256" "$(/usr/bin/basename "$DMG_PATH")" > "$RELEASE_DIR/SHA256SUMS.txt"
/usr/bin/printf 'Created %s\nSHA-256 %s\nSigning: %s\n' "$DMG_PATH" "$SHA256" "$SIGN_IDENTITY"
