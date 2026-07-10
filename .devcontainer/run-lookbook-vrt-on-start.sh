#!/usr/bin/env bash
# One-shot Playwright run after devcontainer web is up.
set -euo pipefail

ROOT=/srv/app
cd "$ROOT"

if [[ "${LOOKBOOK_VRT:-0}" != "1" ]]; then
  echo "==> LOOKBOOK_VRT is not 1 — skipping Lookbook VRT"
  exit 0
fi

echo "==> Waiting for Rails test server (web:3001)…"
for _ in $(seq 1 120); do
  if curl -sf http://web:3001/lookbook >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! curl -sf http://web:3001/lookbook >/dev/null 2>&1; then
  echo "WARN: web:3001 not ready — skipping Lookbook VRT (set LOOKBOOK_VRT=1 on web service)" >&2
  exit 0
fi

echo "==> Running Playwright visual regression tests"
cd "$ROOT/visual-regression"
npm ci
set +e
npx playwright test --reporter=list
TEST_EXIT=$?
set -e

if [[ "$TEST_EXIT" -ne 0 ]]; then
  echo "Lookbook VRT: snapshot mismatches detected (exit $TEST_EXIT)"
else
  echo "Lookbook VRT: all previews passed"
fi

exit 0
