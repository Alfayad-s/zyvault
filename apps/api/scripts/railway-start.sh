#!/bin/sh
set -e

if [ -n "$FIREBASE_SERVICE_ACCOUNT_JSON" ]; then
  printf '%s' "$FIREBASE_SERVICE_ACCOUNT_JSON" > /app/apps/api/firebase-service-account.json
  export FIREBASE_SERVICE_ACCOUNT=/app/apps/api/firebase-service-account.json
fi

exec node /app/apps/api/dist/main.js
