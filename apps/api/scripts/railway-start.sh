#!/bin/sh
set -e

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)

if [ -n "$FIREBASE_SERVICE_ACCOUNT_JSON" ]; then
  printf '%s' "$FIREBASE_SERVICE_ACCOUNT_JSON" > "$ROOT/firebase-service-account.json"
  export FIREBASE_SERVICE_ACCOUNT="$ROOT/firebase-service-account.json"
fi

exec node "$ROOT/dist/main.js"
