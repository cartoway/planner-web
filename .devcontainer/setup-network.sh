#!/bin/bash
# Script to create the shared Docker network public-network
# To be executed once before using Docker Compose projects

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to workspace directory to ensure we're in the right context
cd "$WORKSPACE_DIR"

NETWORK_NAME="public-network"

echo "Checking network $NETWORK_NAME..."

# Clean up stopped containers that might reference old networks
echo "Cleaning up stopped containers..."
docker container prune -f >/dev/null 2>&1 || true

# Clean up orphaned networks, but preserve public-network
echo "Cleaning up orphaned networks (preserving $NETWORK_NAME)..."
# Get list of networks to prune (excluding public-network)
NETWORKS_TO_PRUNE=$(docker network ls --filter "type=custom" --format "{{.Name}}" | grep -v "^${NETWORK_NAME}$" | grep -v "^bridge$" | grep -v "^host$" | grep -v "^none$" || true)
if [ -n "$NETWORKS_TO_PRUNE" ]; then
    # Prune only networks that are not in use
    for net in $NETWORKS_TO_PRUNE; do
        if ! docker network inspect "$net" --format '{{range .Containers}}{{.Name}}{{end}}' 2>/dev/null | grep -q .; then
            docker network rm "$net" 2>/dev/null || true
        fi
    done
fi

# Check if network exists, create if not
if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "✓ Network $NETWORK_NAME already exists"
    NETWORK_ID=$(docker network inspect "$NETWORK_NAME" --format '{{.Id}}')
    echo "  ID: $NETWORK_ID"
    docker network inspect "$NETWORK_NAME" --format '  Driver: {{.Driver}}'
    docker network inspect "$NETWORK_NAME" --format '  Scope: {{.Scope}}'

    # Check for containers still using this network (should be none if external)
    CONTAINERS=$(docker ps -a --filter "network=$NETWORK_NAME" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$CONTAINERS" ]; then
        echo "  Warning: Found containers using this network:"
        echo "$CONTAINERS" | sed 's/^/    /'
    fi
else
    echo "Creating network $NETWORK_NAME..."
    docker network create "$NETWORK_NAME"
    echo "✓ Network $NETWORK_NAME created successfully"
fi

# Verify network exists
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    echo "ERROR: Failed to create or verify network $NETWORK_NAME" >&2
    exit 1
fi

# Verify network is actually usable by running an ephemeral container on it
echo "Verifying network connectivity..."
if docker run --rm --network "$NETWORK_NAME" alpine:3 true 2>/dev/null; then
    echo "✓ Network $NETWORK_NAME is accessible"
else
    echo "ERROR: Network $NETWORK_NAME exists but cannot be used by containers" >&2
    echo "  Try removing and recreating it:"
    echo "    docker network rm $NETWORK_NAME"
    echo "    docker network create $NETWORK_NAME"
    exit 1
fi

echo ""
echo "Network is ready to be used by all Docker Compose projects."

