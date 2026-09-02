#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
APP_NAME="Wikey"
BUNDLE_ID="com.wikey.app"
MIN_SYSTEM_VERSION="15.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build-bundle"
MODULE_CACHE="$BUILD_DIR/module-cache"
MODULE_DIR="$BUILD_DIR/modules"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
HELPER_BUNDLE="$APP_CONTENTS/Library/LoginItems/WikeyLoginHelper.app"
HELPER_CONTENTS="$HELPER_BUNDLE/Contents"

SWIFTC="$(xcrun --find swiftc)"
SDK_PATH="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="$ARCH-apple-macosx$MIN_SYSTEM_VERSION"
SWIFT_INTERFACE="$(find "$SDK_PATH/usr/lib/swift/Swift.swiftmodule" -name '*-apple-macos.swiftinterface' -print -quit)"
SDK_COMPILER_VERSION="$(sed -n 's|// swift-compiler-version: Apple Swift version \([^ ]*\).*|\1|p' "$SWIFT_INTERFACE")"

if [[ -z "$SDK_COMPILER_VERSION" ]]; then
  echo "Could not determine the SDK Swift compiler version." >&2
  exit 1
fi

COMMON_FLAGS=(
  -swift-version 5
  -target "$TARGET"
  -sdk "$SDK_PATH"
  -module-cache-path "$MODULE_CACHE"
  -Xfrontend -interface-compiler-version
  -Xfrontend "$SDK_COMPILER_VERSION"
)

CORE_SOURCES=(
  "$ROOT_DIR"/Sources/WikeyCore/Models/*.swift
  "$ROOT_DIR"/Sources/WikeyCore/Stores/*.swift
  "$ROOT_DIR"/Sources/WikeyCore/Services/*.swift
)
APP_SOURCES=(
  "$ROOT_DIR"/Sources/Wikey/App/*.swift
  "$ROOT_DIR"/Sources/Wikey/Views/*.swift
)

rm -rf "$BUILD_DIR" "$APP_BUNDLE"
mkdir -p "$MODULE_CACHE" "$MODULE_DIR" "$APP_MACOS" "$APP_FRAMEWORKS" "$HELPER_CONTENTS/MacOS"

"$SWIFTC" "${COMMON_FLAGS[@]}" \
  -emit-library -emit-module -parse-as-library \
  -module-name WikeyCore \
  -emit-module-path "$MODULE_DIR/WikeyCore.swiftmodule" \
  -o "$APP_FRAMEWORKS/libWikeyCore.dylib" \
  "${CORE_SOURCES[@]}" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework Carbon \
  -framework ServiceManagement \
  -Xlinker -install_name \
  -Xlinker @rpath/libWikeyCore.dylib

"$SWIFTC" "${COMMON_FLAGS[@]}" \
  -parse-as-library \
  -I "$MODULE_DIR" \
  -L "$APP_FRAMEWORKS" \
  -lWikeyCore \
  "${APP_SOURCES[@]}" \
  -o "$APP_MACOS/$APP_NAME" \
  -framework AppKit \
  -framework SwiftUI \
  -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks

"$SWIFTC" "${COMMON_FLAGS[@]}" \
  "$ROOT_DIR/Sources/WikeyLoginHelper/main.swift" \
  -o "$HELPER_CONTENTS/MacOS/WikeyLoginHelper" \
  -framework AppKit

cp "$ROOT_DIR/Resources/Wikey-Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/WikeyLoginHelper-Info.plist" "$HELPER_CONTENTS/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable WikeyLoginHelper" "$HELPER_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.wikey.login-helper" "$HELPER_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName WikeyLoginHelper" "$HELPER_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDevelopmentRegion en" "$HELPER_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$HELPER_CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$HELPER_CONTENTS/Info.plist"

chmod +x "$APP_MACOS/$APP_NAME" "$HELPER_CONTENTS/MacOS/WikeyLoginHelper"

SIGNING_IDENTITY="${WIKEY_CODESIGN_IDENTITY:--}"
SIGNING_ARGS=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  SIGNING_ARGS+=(--options runtime --timestamp)
fi

codesign "${SIGNING_ARGS[@]}" "$APP_FRAMEWORKS/libWikeyCore.dylib"
codesign "${SIGNING_ARGS[@]}" "$HELPER_BUNDLE"
codesign "${SIGNING_ARGS[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "$APP_BUNDLE"
