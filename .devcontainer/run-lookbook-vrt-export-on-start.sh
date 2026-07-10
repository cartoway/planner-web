#!/usr/bin/env bash
# Writes public/lookbook-visual-regression/manifest.json after Playwright (when enabled).
set -euo pipefail

if [[ "${LOOKBOOK_VRT:-0}" != "1" ]]; then
  echo "==> LOOKBOOK_VRT is not 1 — skipping Lookbook VRT report export"
  exit 0
fi

exec ruby /srv/app/script/export_lookbook_visual_regression_report.rb
