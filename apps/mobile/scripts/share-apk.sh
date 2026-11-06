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
SITE_DIR="$ROOT_DIR/apps/website/public"
API_BASE_URL="https://zyvault-production.up.railway.app"

build_one() {
  local flavor="$1"
  local define="$2"
  local name="$3"
  local built="$MOBILE_DIR/build/app/outputs/flutter-apk/app-${flavor}-release.apk"
  echo "Building $flavor APK for $API_BASE_URL"
  flutter build apk --release --flavor "$flavor" --dart-define="UPI_ALERTS=$define" --dart-define=API_BASE_URL="$API_BASE_URL"
  if [[ ! -f "$built" ]]; then
    echo "APK not found at $built" >&2
    exit 1
  fi
  cp "$built" "$SHARE_DIR/$name"
  cp "$built" "$SITE_DIR/$name"
  echo "Copied $name"
}

mkdir -p "$SHARE_DIR" "$SITE_DIR"
if [[ "$CLEAN" -eq 1 ]]; then
  find "$SHARE_DIR" -maxdepth 1 -type f -name '*.apk' -delete
fi

cd "$MOBILE_DIR"
build_one alerts true zyvault.apk
build_one basic false zyvault-basic.apk

VERSION_LINE="$(grep -E '^version:' "$MOBILE_DIR/pubspec.yaml" | head -1 | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
VERSION_CODE="${VERSION_LINE##*+}"
python3 - "$SITE_DIR/app-release.json" "$VERSION_CODE" "$VERSION_NAME" <<'PY'
import json, sys
path, code, name = sys.argv[1:]
json.dump({
    "versionCode": int(code),
    "versionName": name,
    "notes": "Chat answers ordinary questions. The home-screen eye hides spending too. Changes made offline stay on the phone and sync later.",
    "alerts": "https://zyvault.clawdage.com/zyvault.apk",
    "basic": "https://zyvault.clawdage.com/zyvault-basic.apk",
}, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY
echo "APKs copied to $SHARE_DIR and $SITE_DIR"
