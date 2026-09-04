#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
APP_NAME="Wikey"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-bundle"
DERIVED_DATA="$BUILD_DIR/DerivedData"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
BUILT_APP="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
SIGNING_IDENTITY="${WIKEY_CODESIGN_IDENTITY:--}"

rm -rf "$BUILD_DIR" "$APP_BUNDLE"
mkdir -p "$DIST_DIR"

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/Wikey.xcodeproj"
  -scheme "$APP_NAME"
  -configuration Release
  -quiet
  -derivedDataPath "$DERIVED_DATA"
  -destination "generic/platform=macOS"
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  CODE_SIGN_STYLE=Manual
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
  DEVELOPMENT_TEAM=""
  clean build
)

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  XCODEBUILD_ARGS+=(ENABLE_HARDENED_RUNTIME=NO)
else
  XCODEBUILD_ARGS+=(CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi

xcodebuild "${XCODEBUILD_ARGS[@]}"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Built app was not found at $BUILT_APP" >&2
  exit 1
fi

ditto --rsrc --extattr "$BUILT_APP" "$APP_BUNDLE"

if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  SPARKLE_FRAMEWORK="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
  SPARKLE_VERSION="$SPARKLE_FRAMEWORK/Versions/B"

  # Xcode's Embed & Sign step does not re-sign Sparkle's nested helpers.
  # Sign them from the inside out, preserving the Downloader entitlement.
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$SPARKLE_VERSION/XPCServices/Installer.xpc"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    --preserve-metadata=entitlements \
    "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$SPARKLE_VERSION/Autoupdate"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$SPARKLE_VERSION/Updater.app"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$SPARKLE_FRAMEWORK"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$APP_BUNDLE/Contents/Frameworks/WikeyCore.framework"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    "$APP_BUNDLE/Contents/Library/LoginItems/WikeyLoginHelper.app"
  codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp \
    --preserve-metadata=identifier,entitlements,requirements \
    "$APP_BUNDLE"

  APP_ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_BUNDLE" 2>&1)"
  if [[ "$APP_ENTITLEMENTS" == *"com.apple.security.get-task-allow"* ]]; then
    echo "Developer ID build contains the forbidden get-task-allow entitlement." >&2
    exit 1
  fi

  for SIGNED_ITEM in \
    "$APP_BUNDLE" \
    "$APP_BUNDLE/Contents/Library/LoginItems/WikeyLoginHelper.app" \
    "$APP_BUNDLE/Contents/Frameworks/WikeyCore.framework" \
    "$SPARKLE_FRAMEWORK" \
    "$SPARKLE_VERSION/Autoupdate" \
    "$SPARKLE_VERSION/Updater.app" \
    "$SPARKLE_VERSION/XPCServices/Downloader.xpc" \
    "$SPARKLE_VERSION/XPCServices/Installer.xpc"; do
    SIGNING_DETAILS="$(codesign -dvvv "$SIGNED_ITEM" 2>&1)"
    if [[ "$SIGNING_DETAILS" != *"flags=0x10000(runtime)"* ]]; then
      echo "A valid Hardened Runtime signature is missing from $SIGNED_ITEM." >&2
      exit 1
    fi
    if [[ "$SIGNING_DETAILS" != *"Timestamp="* ]]; then
      echo "A secure timestamp is missing from $SIGNED_ITEM." >&2
      exit 1
    fi
  done
fi

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
ACTUAL_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_BUNDLE/Contents/Info.plist")"
if [[ "$ACTUAL_VERSION" != "$VERSION" || "$ACTUAL_BUILD" != "$BUILD_NUMBER" ]]; then
  echo "Version mismatch: expected $VERSION ($BUILD_NUMBER), built $ACTUAL_VERSION ($ACTUAL_BUILD)" >&2
  exit 1
fi

if [[ ! -d "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework" ]]; then
  echo "Sparkle.framework is missing from the app bundle." >&2
  exit 1
fi

FEED_URL="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_BUNDLE/Contents/Info.plist")"
PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_BUNDLE/Contents/Info.plist")"
if [[ "$FEED_URL" != "https://raw.githubusercontent.com/movvgli/Wikey/update-feed/appcast.xml" ]]; then
  echo "Unexpected Sparkle feed URL: $FEED_URL" >&2
  exit 1
fi
if [[ -z "$PUBLIC_KEY" ]]; then
  echo "Sparkle public key is missing." >&2
  exit 1
fi

echo "$APP_BUNDLE"
