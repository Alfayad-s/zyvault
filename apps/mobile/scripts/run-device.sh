#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3000}"

adb_reverse() {
  local adb="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}/platform-tools/adb"
  [[ -x "$adb" ]] || return 1
  local serials
  serials="$("$adb" devices 2>/dev/null | awk 'NR>1 && $2=="device" { print $1 }')"
  [[ -n "$serials" ]] || return 1
  local serial
  while IFS= read -r serial; do
    [[ -n "$serial" ]] || continue
    "$adb" -s "$serial" reverse "tcp:${PORT}" "tcp:${PORT}" >/dev/null
  done <<<"$serials"
}

if [[ -z "${API_HOST:-}" ]] && adb_reverse; then
  API_BASE_URL="http://127.0.0.1:${PORT}"
  echo "Android is on USB, so the app uses $API_BASE_URL through adb reverse."
  echo "Start the API with pnpm dev. Wi-Fi is not required while the cable is connected."
else
  if [[ -n "${API_HOST:-}" ]]; then
    IP="$API_HOST"
  else
    IP=""
    for iface in en0 en1 bridge0; do
      IP="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
      if [[ -n "$IP" ]]; then
        break
      fi
    done
    if [[ -z "$IP" ]]; then
      IP="$(ifconfig | awk '/inet / && $2 != "127.0.0.1" { print $2; exit }')"
    fi
  fi

  if [[ -z "${IP:-}" ]]; then
    echo "Could not detect a LAN IP. Set API_HOST, for example: API_HOST=192.168.1.20 pnpm dev:mobile:device" >&2
    exit 1
  fi

  API_BASE_URL="http://${IP}:${PORT}"
  echo "Backend URL for this device: $API_BASE_URL"
  echo "Start the API with pnpm dev. The phone and this computer must be on the same Wi-Fi."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$MOBILE_DIR"
exec flutter run --dart-define=API_BASE_URL="$API_BASE_URL" "$@"
