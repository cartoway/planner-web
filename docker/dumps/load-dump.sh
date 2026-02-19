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

# Find the dump file: exact match first, then first .pg_dump.gz found
DUMP_FILE="$INIT_DIR/${POSTGRES_DB}.pg_dump.gz"
if [ ! -f "$DUMP_FILE" ]; then
    DUMP_FILE=$(find "$INIT_DIR" -maxdepth 1 -name '*.pg_dump.gz' -type f | head -n 1)
fi

if [ -n "$DUMP_FILE" ] && [ -f "$DUMP_FILE" ]; then
    echo "Loading dump from $DUMP_FILE into database '$POSTGRES_DB'..."

    # Detect format by checking file header (first bytes)
    FIRST_BYTES=$(head -c 5 "$DUMP_FILE" 2>/dev/null || echo "")
    DUMP_TYPE=$(file "$DUMP_FILE" 2>/dev/null || echo "")

    if echo "$FIRST_BYTES" | grep -q "PGDMP" || echo "$DUMP_TYPE" | grep -q "PostgreSQL custom database dump"; then
        if echo "$DUMP_TYPE" | grep -q "gzip"; then
            echo "Detected gzipped PostgreSQL custom format, decompressing and loading with pg_restore..."
            gunzip -c "$DUMP_FILE" | pg_restore -v --no-owner --no-acl --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
        else
            echo "Detected PostgreSQL custom format (not compressed), loading directly with pg_restore..."
            pg_restore -v --no-owner --no-acl --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" "$DUMP_FILE"
        fi
    elif echo "$DUMP_TYPE" | grep -q "gzip"; then
        echo "Detected gzipped plain SQL format, loading with psql..."
        gunzip -c "$DUMP_FILE" | psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"
    else
        echo "Detected plain SQL format, loading with psql..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < "$DUMP_FILE"
    fi

    echo "Dump loaded successfully!"
else
    echo "No dump file found at $DUMP_FILE, skipping..."
fi
