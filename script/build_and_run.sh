#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Wikey"
BUNDLE_ID="com.wikey.app"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

VERSION="${WIKEY_VERSION:-$(sed -n 's/.*MARKETING_VERSION: "\([^"]*\)"/\1/p' "$ROOT_DIR/project.yml" | head -n 1)}"
BUILD_NUMBER="${WIKEY_BUILD_NUMBER:-$(sed -n 's/.*CURRENT_PROJECT_VERSION: "\([^"]*\)"/\1/p' "$ROOT_DIR/project.yml" | head -n 1)}"
if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "Could not resolve Wikey version from project.yml." >&2
  exit 1
fi

# Reuse the installed app's developer identity to preserve privacy authorization.
INSTALLED_APP="/Applications/$APP_NAME.app"
if [[ -d "$INSTALLED_APP" && -z "${WIKEY_CODESIGN_IDENTITY:-}" ]]; then
  INSTALLED_TEAM="$(codesign -dv "$INSTALLED_APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
  if [[ -n "$INSTALLED_TEAM" && "$INSTALLED_TEAM" != "not set" ]]; then
    WIKEY_CODESIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F '\"' -v team="$INSTALLED_TEAM" 'index($2, "Developer ID Application:") == 1 && index($2, "(" team ")") { print $2; exit }')"
    if [[ -z "$WIKEY_CODESIGN_IDENTITY" ]]; then
      echo "The installed app's Developer ID signing identity is unavailable." >&2
      exit 1
    fi
    export WIKEY_CODESIGN_IDENTITY
  fi
fi

"$ROOT_DIR/script/build_bundle.sh" "$VERSION" "$BUILD_NUMBER"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "WikeyLoginHelper" >/dev/null 2>&1 || true

if [[ -d "$INSTALLED_APP" && "${WIKEY_CODESIGN_IDENTITY:--}" != "-" ]]; then
  BACKUP_DIR="$(mktemp -d /tmp/wikey-app-backup.XXXXXX)"
  mv "$INSTALLED_APP" "$BACKUP_DIR/$APP_NAME.app"
  if ! ditto "$APP_BUNDLE" "$INSTALLED_APP"; then
    # Keep the incomplete copy for diagnosis and restore the runnable app.
    if [[ -e "$INSTALLED_APP" ]]; then
      mv "$INSTALLED_APP" "$BACKUP_DIR/Incomplete-$APP_NAME.app"
    fi
    mv "$BACKUP_DIR/$APP_NAME.app" "$INSTALLED_APP"
    echo "Could not install the new app. The previous app has been restored." >&2
    exit 1
  fi
  APP_BUNDLE="$INSTALLED_APP"
  APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  echo "Previous app saved at $BACKUP_DIR/$APP_NAME.app"
fi

open_app() {
  if [[ -n "${WIKEY_TEST_STORE:-}" ]]; then
    /usr/bin/open -n "$APP_BUNDLE" --args --test-store "$WIKEY_TEST_STORE"
  else
    /usr/bin/open -n "$APP_BUNDLE"
  fi
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
