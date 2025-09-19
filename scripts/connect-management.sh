#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENT_DIR="$PROJECT_ROOT/infrastructure"

# Load environment configuration
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Warning: .env file not found, using defaults"
    MAIN_NETWORK="${MAIN_NETWORK:-wireguard}"
fi

# Get management node IP based on MAIN_NETWORK setting
case "${MAIN_NETWORK:-wireguard}" in
    "wireguard")
        MANAGEMENT_IP=$(tofu -chdir="$DEPLOYMENT_DIR" output -raw management_node_wireguard_ip)
        NETWORK_TYPE="WireGuard"
        ;;
    "mycelium")
        MANAGEMENT_IP=$(tofu -chdir="$DEPLOYMENT_DIR" output -raw management_mycelium_ip)
        NETWORK_TYPE="Mycelium"
        ;;
    *)
        echo "Error: Invalid MAIN_NETWORK: ${MAIN_NETWORK}. Use 'wireguard' or 'mycelium'"
        exit 1
        ;;
esac

if [ -z "$MANAGEMENT_IP" ]; then
    echo "Error: Could not retrieve management node $NETWORK_TYPE IP."
    exit 1
fi

echo "Connecting to management node at $MANAGEMENT_IP (via $NETWORK_TYPE)..."
ssh root@$MANAGEMENT_IP
