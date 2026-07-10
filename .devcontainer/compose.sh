#!/usr/bin/env bash
# Build and run planner-web containers using .devcontainer Docker setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPOSE_ARGS=(
  -f "$SCRIPT_DIR/docker-compose.yml"
  -f "$SCRIPT_DIR/docker-compose-qr-shortener.yml"
  -f "$SCRIPT_DIR/docker-compose-superset.yml"
)

cd "$ROOT_DIR"

setup_network() {
  bash "$SCRIPT_DIR/setup-network.sh"
}

compose() {
  docker compose "${COMPOSE_ARGS[@]}" "$@"
}

load_env() {
  if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ROOT_DIR/.env"
    set +a
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  up        Start containers in background (default, runs setup-network first)
            Includes web, db, url shortener, and Superset (http://127.0.0.1:8088)
            Lookbook VRT runs only when LOOKBOOK_VRT=1 in .env
  build     Build images (runs setup-network first)
  down      Stop and remove containers
  restart   Restart services
  logs      Follow container logs
  ps        List containers
  exec      Run a command in a service (e.g. exec web bash)
  run       Run a one-off command (e.g. run --rm web bundle exec rake db:migrate)
  test      Run the test suite (RAILS_ENV=test, uses POSTGRES_DB_TEST, not production DB)
  test-prepare
            Create or refresh the test database (run once after first setup)

Any other command is passed through to docker compose.

Examples:
  $(basename "$0") up --build
  $(basename "$0") build
  $(basename "$0") logs -f web
EOF
}

main() {
  local command="${1:-up}"

  case "$command" in
    -h|--help|help)
      usage
      ;;
    build|up|restart)
      setup_network
      load_env
      compose "$@"
      ;;
    test-prepare)
      compose exec \
        -e RAILS_ENV=test \
        -e COV=false \
        -e COVERAGE=false \
        web bundle exec rails db:test:prepare
      ;;
    test)
      shift
      compose exec \
        -e RAILS_ENV=test \
        -e COV=false \
        -e COVERAGE=false \
        web bundle exec rails test "$@"
      ;;
    down|logs|ps|exec|run|pull|stop|start|top|config)
      compose "$@"
      ;;
    *)
      setup_network
      compose "$@"
      ;;
  esac
}

main "$@"
