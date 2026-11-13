#!/usr/bin/env bash
# Run Node self-checks under test/javascript (not picked up by minitest).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

shopt -s nullglob
files=(test/javascript/*.mjs test/javascript/*.cjs test/javascript/*.js)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "No frontend JS checks found under test/javascript/" >&2
  exit 1
fi

failed=0
for f in "${files[@]}"; do
  echo "==> node $f"
  if ! node "$f"; then
    echo "FAIL: $f" >&2
    failed=1
  fi
done

exit "$failed"
