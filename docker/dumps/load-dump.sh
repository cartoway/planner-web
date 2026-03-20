#!/bin/bash
set -e

# Script to load PostgreSQL dump from compressed file
# This script is executed automatically by PostgreSQL container on first startup

INIT_DIR="/docker-entrypoint-initdb.d"

# Skip if database already has tables (dump already loaded)
TABLE_COUNT=$(psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'" 2>/dev/null || echo "0")
if [ "$TABLE_COUNT" -gt 0 ] 2>/dev/null; then
    echo "Database '$POSTGRES_DB' already has $TABLE_COUNT tables, skipping dump load."
    exit 0
fi

# Find the dump file: exact match first, then first supported dump extension.
# Accept dumps with or without ".pg_dump" in the filename.
DUMP_FILE=""
for exact in \
  "$INIT_DIR/${POSTGRES_DB}.sql" \
  "$INIT_DIR/${POSTGRES_DB}.zst" \
  "$INIT_DIR/${POSTGRES_DB}.gz"
do
    if [ -f "$exact" ]; then
        DUMP_FILE="$exact"
        break
    fi
done

if [ -z "$DUMP_FILE" ]; then
    for fallback in \
      "$INIT_DIR"/*.sql \
      "$INIT_DIR"/*.zst \
      "$INIT_DIR"/*.gz
    do
        if [ -f "$fallback" ]; then
            DUMP_FILE="$fallback"
            break
        fi
    done
fi

if [ -n "$DUMP_FILE" ] && [ -f "$DUMP_FILE" ]; then
    echo "Loading dump from $DUMP_FILE into database '$POSTGRES_DB'..."

    # Detect compression by extension and detect dump format by reading the first bytes
    if [[ "$DUMP_FILE" == *.zst ]]; then
        command -v zstd >/dev/null 2>&1 || { echo "zstd command not found, cannot read $DUMP_FILE"; exit 1; }
        FIRST_BYTES=$(zstd -dc "$DUMP_FILE" 2>/dev/null | head -c 5 || echo "")
        COMPRESSED_TYPE="zstd"
    elif [[ "$DUMP_FILE" == *.gz ]]; then
        FIRST_BYTES=$(gunzip -c "$DUMP_FILE" 2>/dev/null | head -c 5 || echo "")
        COMPRESSED_TYPE="gzip"
    else
        FIRST_BYTES=$(head -c 5 "$DUMP_FILE" 2>/dev/null || echo "")
        COMPRESSED_TYPE="none"
    fi

    if echo "$FIRST_BYTES" | grep -q "PGDMP"; then
        if [ "$COMPRESSED_TYPE" = "zstd" ]; then
            echo "Detected zstd PostgreSQL custom format, decompressing and loading with pg_restore..."
            zstd -dc "$DUMP_FILE" | pg_restore -v --no-owner --no-acl --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
        elif [ "$COMPRESSED_TYPE" = "gzip" ]; then
            echo "Detected gzipped PostgreSQL custom format, decompressing and loading with pg_restore..."
            gunzip -c "$DUMP_FILE" | pg_restore -v --no-owner --no-acl --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
        else
            echo "Detected PostgreSQL custom format (not compressed), loading directly with pg_restore..."
            pg_restore -v --no-owner --no-acl --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" "$DUMP_FILE"
        fi
    else
        if [ "$COMPRESSED_TYPE" = "zstd" ]; then
            echo "Detected zstd plain SQL format, loading with psql..."
            zstd -dc "$DUMP_FILE" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
        elif [ "$COMPRESSED_TYPE" = "gzip" ]; then
            echo "Detected gzipped plain SQL format, loading with psql..."
            gunzip -c "$DUMP_FILE" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
        else
            echo "Detected plain SQL format, loading with psql..."
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$DUMP_FILE"
        fi
    fi

    echo "Dump loaded successfully!"
else
    echo "No dump file found at $DUMP_FILE, skipping..."
fi
