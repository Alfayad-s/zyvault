#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-3000}"

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Backend URL for this device: $API_BASE_URL"
echo "Start the API with pnpm dev. The phone and this computer must be on the same Wi-Fi."

cd "$MOBILE_DIR"
exec flutter run --dart-define=API_BASE_URL="$API_BASE_URL" "$@"
