#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
APP_NAME="Wikey"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_ROOT="$ROOT_DIR/.build-bundle/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"

"$ROOT_DIR/script/build_bundle.sh" "$VERSION" "$BUILD_NUMBER"

rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

rm -f "$DMG_PATH" "$CHECKSUM_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
hdiutil verify "$DMG_PATH"

SIGNING_IDENTITY="${WIKEY_CODESIGN_IDENTITY:--}"
NOTARY_PROFILE="${WIKEY_NOTARY_PROFILE:-}"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
fi

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo "WIKEY_NOTARY_PROFILE requires a Developer ID identity in WIKEY_CODESIGN_IDENTITY." >&2
    exit 1
  fi
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
else
  echo "Created an ad-hoc signed local DMG. Set WIKEY_CODESIGN_IDENTITY and WIKEY_NOTARY_PROFILE for public distribution."
fi

shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"
echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
