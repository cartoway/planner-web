# Source this file to use planner-web devcontainer aliases:
#   source /path/to/planner-web/.devcontainer/aliases.sh
#
# Or add to ~/.bashrc:
#   source ~/projects/planner-web/.devcontainer/aliases.sh

_planner_web_devcontainer() {
  local root
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  bash "$root/.devcontainer/compose.sh" "$@"
}

alias planner-dev='_planner_web_devcontainer'
alias planner-dev-up='_planner_web_devcontainer up --build -d'  # Superset: http://127.0.0.1:8088 (admin/admin)
alias planner-dev-build='_planner_web_devcontainer build'
alias planner-dev-down='_planner_web_devcontainer down'
alias planner-dev-logs='_planner_web_devcontainer logs -f'

# Tests must use RAILS_ENV=test and a separate database (POSTGRES_DB_TEST / planner-test).
# Without this, db:test:purge would wipe the production database (POSTGRES_DB / planner).
planner-dev-test-prepare() {
  _planner_web_devcontainer exec \
    -e RAILS_ENV=test \
    -e COV=false \
    -e COVERAGE=false \
    web bundle exec rails db:test:prepare
}

planner-dev-test() {
  _planner_web_devcontainer exec \
    -e RAILS_ENV=test \
    -e COV=false \
    -e COVERAGE=false \
    web bundle exec rails test "$@"
}

alias planner-dev-test-prepare='planner-dev-test-prepare'
alias planner-dev-test='planner-dev-test'

# Lookbook visual regression (Playwright in Ubuntu container; web image is Alpine).
# Usage: planner-dev-vrt test | update | report | prepare
planner-dev-vrt() {
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/visual-regression.sh" "$@"
}
alias planner-dev-vrt='planner-dev-vrt'
