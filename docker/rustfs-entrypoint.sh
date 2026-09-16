#!/bin/sh
# Start RustFS, then create the photos bucket with curl (no extra aws-cli container).
set -eu

/entrypoint.sh rustfs &
pid=$!
trap 'kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null' INT TERM

bucket="${RUSTFS_BUCKET:-planner-photos}"
region="${RUSTFS_REGION:-eu-west-3}"
key="${RUSTFS_ACCESS_KEY:-rustfsadmin}"
secret="${RUSTFS_SECRET_KEY:-rustfsadmin}"

i=0
until curl -fsS http://127.0.0.1:9000/health >/dev/null 2>&1; do
  kill -0 "$pid" 2>/dev/null || exit 1
  i=$((i + 1))
  [ "$i" -gt 60 ] && exit 1
  sleep 1
done

code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT \
  --aws-sigv4 "aws:amz:${region}:s3" \
  --user "${key}:${secret}" \
  "http://127.0.0.1:9000/${bucket}") || true

case "$code" in
  200|409) touch /tmp/bucket-ready ;;
  *)
    echo "rustfs: failed to create bucket ${bucket} (HTTP ${code})" >&2
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    exit 1
    ;;
esac

wait "$pid"
