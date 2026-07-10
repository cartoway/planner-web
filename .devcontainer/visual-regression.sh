#!/usr/bin/env bash
# Visual regression via Playwright in Docker (devcontainer network).
# The web image is Alpine: Chromium cannot run inside it. This script starts
# Rails test on web:3001 and runs Playwright in the official Ubuntu image.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE="$SCRIPT_DIR/compose.sh"
PLAYWRIGHT_IMAGE="${PLAYWRIGHT_IMAGE:-mcr.microsoft.com/playwright:v1.49.1-jammy}"
NETWORK="${PLAYWRIGHT_DOCKER_NETWORK:-public-network}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [playwright args...]

Commands:
  prepare   Compile Webpacker (test), prepare DB, start Rails on web:3001
  test      Run Playwright (default reporter: html + list)
  update    Run Playwright with --update-snapshots
  report    Serve HTML report on http://127.0.0.1:9323 (after a failing test run)

Examples:
  $(basename "$0") test
  $(basename "$0") test -g 'lookbook: buttons-variants'
  $(basename "$0") update -g 'lookbook: buttons-variants'
  $(basename "$0") report

Requires planner-dev (web + db) running on network ${NETWORK}.
Snapshots and reports are written to the workspace via volume mount (same as CI baselines).
EOF
}

compose_exec() {
  bash "$COMPOSE" exec \
    -e RAILS_ENV=test \
    -e DATABASE_URL=postgres://planner:planner@db:5432/planner-test \
    web "$@"
}

rails_test_ready() {
  compose_exec curl -sf http://127.0.0.1:3001/lookbook >/dev/null 2>&1
}

prepare_rails_test() {
  if rails_test_ready; then
    echo "==> Rails test server already listening on web:3001 (skipping db:test:prepare)"
    return
  fi

  echo "==> Webpacker (test) + db:test:prepare in web container"
  compose_exec sh -c '
    cd /srv/app
    NODE_ENV=test bundle exec rails webpacker:compile
    bundle exec rails db:test:prepare
  '

  echo "==> Starting Rails test server on web:3001 (background)"
  bash "$COMPOSE" exec -d \
    -e RAILS_ENV=test \
    -e DATABASE_URL=postgres://planner:planner@db:5432/planner-test \
    web sh -c 'cd /srv/app && bundle exec rails server -e test -p 3001 -b 0.0.0.0'

  for _ in $(seq 1 60); do
    if rails_test_ready; then
      echo "==> Rails test server ready"
      return
    fi
    sleep 2
  done

  echo "ERROR: Rails test server did not start on port 3001 inside web container." >&2
  exit 1
}

run_playwright() {
  cd "$ROOT_DIR"
  docker run --rm \
    --network "$NETWORK" \
    -v "$ROOT_DIR:/srv/app" \
    -w /srv/app/visual-regression \
    -e PLAYWRIGHT_SKIP_WEBSERVER=1 \
    -e PLAYWRIGHT_BASE_URL=http://web:3001 \
    -e PLAYWRIGHT_HTML_OPEN=never \
    "$PLAYWRIGHT_IMAGE" \
    bash -c 'npm ci && npx playwright test "$@"' _ "$@"
}

run_report() {
  cd "$ROOT_DIR"
  if [[ ! -d visual-regression/playwright-report ]]; then
    echo "No report found. Run: $(basename "$0") test" >&2
    exit 1
  fi
  docker run --rm -it \
    -p 127.0.0.1:9323:9323 \
    -v "$ROOT_DIR:/srv/app" \
    -w /srv/app/visual-regression \
    "$PLAYWRIGHT_IMAGE" \
    npx playwright show-report --host 0.0.0.0 --port 9323
}

export_report() {
  cd "$ROOT_DIR"
  if bash "$COMPOSE" ps --status running web >/dev/null 2>&1; then
    bash "$COMPOSE" exec web ruby /srv/app/script/export_lookbook_visual_regression_report.rb
  else
    ruby script/export_lookbook_visual_regression_report.rb
  fi
  echo "Lookbook report: http://localhost:8080/lookbook/preview/design_system/visual_regression/report"
}

main() {
  local command="${1:-}"
  shift || true

  case "$command" in
    -h|--help|help|'')
      usage
      exit 0
      ;;
    prepare)
      prepare_rails_test
      ;;
    test)
      prepare_rails_test
      run_playwright --reporter=html,list "$@"
      export_report
      ;;
    update)
      prepare_rails_test
      run_playwright --update-snapshots "$@"
      export_report
      ;;
    export)
      export_report
      ;;
    report)
      run_report
      ;;
    *)
      echo "Unknown command: $command" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
