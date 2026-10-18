#!/usr/bin/env bash
set -euo pipefail

CLEAN=0
if [[ "${1:-}" == "--clean" ]]; then
  CLEAN=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$MOBILE_DIR/../.." && pwd)"
SHARE_DIR="$ROOT_DIR/share-apk"
APK_NAME="finance-track-release.apk"
BUILT_APK="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"

cd "$MOBILE_DIR"
flutter build apk

if [[ ! -f "$BUILT_APK" ]]; then
  echo "APK not found at $BUILT_APK" >&2
  exit 1
fi

mkdir -p "$SHARE_DIR"

if [[ "$CLEAN" -eq 1 ]]; then
  find "$SHARE_DIR" -maxdepth 1 -type f -name '*.apk' -delete
fi

cp "$BUILT_APK" "$SHARE_DIR/$APK_NAME"
echo "APK copied to $SHARE_DIR/$APK_NAME"
