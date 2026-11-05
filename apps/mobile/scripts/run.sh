#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

device=""
expect_device=0
for arg in "$@"; do
  if [[ "$expect_device" -eq 1 ]]; then
    device="$arg"
    expect_device=0
    continue
  fi
  case "$arg" in
    -d|--device-id)
      expect_device=1
      ;;
    -d*)
      device="${arg#-d}"
      ;;
  esac
done

platform="$(
  flutter devices --machine | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
wanted = sys.argv[1]
if not raw:
    print("other")
    raise SystemExit
devices = json.loads(raw)

def platform_of(device):
    return str(device.get("targetPlatform") or "")

if wanted:
    for device in devices:
        if wanted in (device.get("id"), device.get("name")):
            print(platform_of(device))
            break
    else:
        if wanted in ("ios", "apple"):
            print("ios")
        elif wanted == "android":
            print("android")
        else:
            print("other")
    raise SystemExit

mobiles = [device for device in devices if platform_of(device).startswith(("ios", "android"))]
if len(mobiles) == 1:
    print(platform_of(mobiles[0]))
elif mobiles and all(platform_of(device).startswith("ios") for device in mobiles):
    print("ios")
elif mobiles and all(platform_of(device).startswith("android") for device in mobiles):
    print("android")
elif len(mobiles) > 1:
    print("mixed")
else:
    print("other")
' "$device"
)"

args=(flutter run --dart-define=UPI_ALERTS=true)
case "$platform" in
  android*)
    args+=(--flavor alerts)
    ;;
  mixed)
    echo "More than one phone is available. Run again with -d and the device id." >&2
    exit 1
    ;;
esac

exec "${args[@]}" "$@"
