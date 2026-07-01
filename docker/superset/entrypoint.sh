#!/bin/bash
set -e

# Check if Superset database exists, create it if not
export PGPASSWORD="$POSTGRES_PASSWORD"
if ! psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$SUPERSET_DB'" | grep -q 1; then
    echo "Creating Superset database..."
    psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE $SUPERSET_DB;"
fi
unset PGPASSWORD

# Check if Superset is initialized (check if ab_user table exists)
export PGPASSWORD="$POSTGRES_PASSWORD"
INITIALIZED=$(psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$SUPERSET_DB" -tc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ab_user');" 2>/dev/null || echo "f")
unset PGPASSWORD

if [ "$INITIALIZED" != "t" ]; then
    echo "Initializing Superset..."
    superset db upgrade
    superset fab create-admin \
        --username "$SUPERSET_ADMIN_USERNAME" \
        --firstname Superset \
        --lastname Admin \
        --email "$SUPERSET_ADMIN_EMAIL" \
        --password "$SUPERSET_ADMIN_PASSWORD" || true
    superset init || true
    PERMISSIONS_FILE="/app/superset-public-permissions.json"
    if [ ! -f "$PERMISSIONS_FILE" ] && [ -f "/app/pythonpath/superset-public-permissions.json" ]; then
        PERMISSIONS_FILE="/app/pythonpath/superset-public-permissions.json"
    fi
    if [ -f "$PERMISSIONS_FILE" ]; then
        superset fab import-roles -p "$PERMISSIONS_FILE" || true
    fi
fi

# Initialize the history_live_routes view
SQL_FILE="/usr/local/share/superset/history_live_routes.sql"
if [ ! -f "$SQL_FILE" ] && [ -f "/app/pythonpath/history_live_routes.sql" ]; then
    SQL_FILE="/app/pythonpath/history_live_routes.sql"
fi

if [ ! -f "$SQL_FILE" ]; then
    echo "Warning: SQL file not found: $SQL_FILE" >&2
else
    echo "Initializing history_live_routes view in database $POSTGRES_DB on $POSTGRES_HOST:$POSTGRES_PORT..."

    export PGPASSWORD="$POSTGRES_PASSWORD"

    # Execute SQL file
    psql -h "$POSTGRES_HOST" \
         -p "$POSTGRES_PORT" \
         -U "$POSTGRES_USER" \
         -d "$POSTGRES_DB" \
         -f "$SQL_FILE" \
         -v ON_ERROR_STOP=1

    unset PGPASSWORD

    echo "✓ history_live_routes view created/updated successfully"
fi

# Start Superset server
exec superset run --host 0.0.0.0 --port 8088
