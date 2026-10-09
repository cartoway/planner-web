#!/usr/bin/env bash
# Copy the working tree into the running web container, refresh digested assets, restart web.
# The web image does not mount the app source, and production serves precompiled digests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

mapfile -t files < <(
  {
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | sort -u | while read -r path; do
    [[ -f "$path" ]] || continue
    case "$path" in
      app/*|config/*|lib/*|vendor/*) printf '%s\n' "$path" ;;
    esac
  done
)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "Nothing to copy (app/, config/, lib/, vendor/)."
  exit 0
fi

cid="$(bash "$SCRIPT_DIR/compose.sh" ps -q web)"
if [[ -z "$cid" ]]; then
  echo "The web service is not running. Start it with planner-dev-up." >&2
  exit 1
fi

needs_v2=0
needs_v1=0
js_paths=()
for path in "${files[@]}"; do
  case "$path" in
    app/assets/stylesheets/v2/*|app/assets/stylesheets/lookbook_preview.scss)
      needs_v2=1
      ;;
    app/javascript/*)
      needs_v2=1
      js_paths+=("${path#app/javascript/}")
      ;;
    vendor/javascript/*)
      needs_v2=1
      js_paths+=("${path#vendor/javascript/}")
      ;;
    app/assets/*|app/javascript/packs/*|app/templates/*)
      needs_v1=1
      ;;
  esac
done

# planner-dev-sync-v2 skips full Sprockets when only Stimulus/v2 CSS changed.
# Packs like planning.js import app/assets/javascripts — those still need webpack.
if [[ "${1:-}" == "--v2" ]]; then
  needs_v1=0
  needs_v2=1
  for path in "${files[@]}"; do
    case "$path" in
      app/assets/javascripts/*|app/templates/*|app/javascript/packs/*)
        needs_v1=1
        break
        ;;
    esac
  done
fi

# Dirty-only copy misses committed asset sources still stale in the container
# (e.g. searchable_checklist_dropdown.scss already committed, but container has an older copy).
# Whenever we touch app/ and will recompile v1 — or any app/assets file is involved —
# push the full tracked asset trees used by digests.
if [[ "$needs_v1" -eq 1 ]]; then
  mapfile -t asset_files < <(
    git ls-files -- 'app/assets' 'app/javascript/packs' | while read -r path; do
      [[ -f "$path" ]] || continue
      printf '%s\n' "$path"
    done
  )
  if [[ ${#asset_files[@]} -gt 0 ]]; then
    mapfile -t files < <(printf '%s\n' "${files[@]}" "${asset_files[@]}" | sort -u)
  fi
fi

echo "Copying ${#files[@]} file(s)…"
# Some paths may be bind-mounted RO into the container (Resource busy / read-only).
# Extract to a temp dir then overwrite when possible; skip when already current.
tar -C "$ROOT_DIR" -cf - "${files[@]}" | docker exec -i "$cid" sh -c '
  set -e
  tmp=$(mktemp -d)
  trap "rm -rf \"$tmp\"" EXIT
  tar -C "$tmp" -xf -
  cd "$tmp"
  find . -type f | while IFS= read -r f; do
    dest="/srv/app/${f#./}"
    mkdir -p "$(dirname "$dest")"
    if cat "$f" > "$dest" 2>/dev/null; then
      continue
    fi
    if cmp -s "$f" "$dest" 2>/dev/null; then
      echo "skip (mounted/read-only, already current): ${f#./}"
      continue
    fi
    echo "WARN: could not update ${f#./}" >&2
  done
'

if [[ "$needs_v1" -eq 1 ]]; then
  echo "Full asset precompile (v1)…"
  # Uglifier 3 cannot parse Turbo 8 / modern Sprockets JS (optional chaining, private fields).
  # Keep yarn/babel/webpacker tooling (devDependencies) available under RAILS_ENV=production.
  # Clear webpacker + sprockets caches so CSS/JS source updates are actually recompiled.
  docker exec -e YARN_PRODUCTION=false -e NODE_ENV=development -w /srv/app "$cid" yarn install --frozen-lockfile
  docker exec -w /srv/app "$cid" sh -c 'rm -rf tmp/cache/webpacker tmp/cache/assets'
  docker exec -e API_DOC_MODE=true -e SKIP_JS_COMPRESSOR=1 -e YARN_PRODUCTION=false -w /srv/app "$cid" bundle exec rake assets:precompile
elif [[ "$needs_v2" -eq 1 ]]; then
  echo "Precompiling v2 assets only…"
  js_list=$(printf '%s\n' "${js_paths[@]:-}" | sort -u | paste -sd, -)
  docker exec -e API_DOC_MODE=true -e V2_JS_PATHS="$js_list" -w /srv/app "$cid" bundle exec ruby -e '
    require "./config/environment"
    app = Rails.application
    app.config.assets.js_compressor = nil
    railtie = Sprockets::Railtie.instance
    env = railtie.build_environment(app, true)
    raise "Sprockets environment missing" unless env
    manifest = Sprockets::Manifest.new(env, File.join("public", "assets"), app.config.assets.manifest)
    logical = %w[v2/application.css v2/layout_bootstrap_overrides.css lookbook_preview.css]
    ENV.fetch("V2_JS_PATHS", "").split(",").each do |path|
      logical << path unless path.empty?
    end
    manifest.compile(*logical.uniq)
  '
fi

echo "Restarting web (cache_classes)…"
bash "$SCRIPT_DIR/compose.sh" restart web
echo "Deployed."
