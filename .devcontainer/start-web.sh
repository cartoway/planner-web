#!/usr/bin/env bash
# Devcontainer web entrypoint: production Puma on 8080 + optional Rails test on 3001 for VRT.
set -euo pipefail

cd /srv/app

if [[ "${LOOKBOOK_VRT:-0}" == "1" ]]; then
  echo "==> Preparing Lookbook VRT (Rails test on :3001)"
  (
    export RAILS_ENV=test
    export DATABASE_URL="postgres://${POSTGRES_USER:-planner}:${POSTGRES_PASSWORD:-planner}@db:5432/${POSTGRES_DB_TEST:-planner-test}"
    NODE_ENV=test bundle exec rails webpacker:compile
    bundle exec rails db:test:prepare
    exec bundle exec rails server -e test -p 3001 -b 0.0.0.0
  ) &
fi

echo "==> Starting Puma on :8080"
exec bundle exec puma -v -p 8080 --pidfile server.pid -t "${PUMA_WORKERS:-0:1}"
