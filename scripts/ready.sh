#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLATFORM_DIR="${REPO_ROOT}/platform"

# Check if infrastructure exists by looking for WireGuard configuration
if [ ! -f "/etc/wireguard/k3s.conf" ]; then
  echo "⚠️ WireGuard configuration not found!"
  echo "Infrastructure must be deployed first. Run:"
  echo "  make infrastructure"
  exit 1
fi

# Check if inventory exists
if [ ! -f "${PLATFORM_DIR}/inventory.ini" ]; then
  echo "⚠️ Ansible inventory not found!"
  echo "Inventory must be generated first. Run:"
  echo "  make inventory"
  exit 1
fi

# --- Check SSH Availability ---
echo "=== Checking SSH Availability ==="
echo "Verifying SSH connectivity to all cluster nodes..."

# SSH check configuration
SSH_CHECK_TIMEOUT=10      # seconds to wait for SSH connection
SSH_RETRY_DELAY=15        # seconds between SSH checks
MAX_SSH_RETRIES=20        # maximum number of SSH check attempts

# Function to check SSH availability for a single host
check_ssh_host() {
  local user=$1
  local ip=$2
  local name=$3

  # Try SSH connection with timeout
  if ssh -o ConnectTimeout=$SSH_CHECK_TIMEOUT \
         -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
         -o PasswordAuthentication=no \
         -o LogLevel=ERROR \
         "$user@$ip" exit 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to check all nodes in inventory
check_all_ssh() {
  local attempt=$1
  local all_ready=true

  echo "SSH Check Attempt $attempt/$MAX_SSH_RETRIES:"

  # Parse inventory and check each node
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue

    # Extract node information
    if [[ "$line" =~ ansible_host ]]; then
      name=$(echo "$line" | awk '{print $1}')
      ip=$(echo "$line" | grep -o "ansible_host=[^ ]*" | cut -d= -f2)
      user=$(echo "$line" | grep -o "ansible_user=[^ ]*" | cut -d= -f2)

      if [ -n "$ip" ] && [ -n "$user" ]; then
        echo -n "  Checking $name ($ip)... "
        if check_ssh_host "$user" "$ip" "$name"; then
          echo "✓"
        else
          echo "✗"
          all_ready=false
        fi
      fi
    fi
  done < "${PLATFORM_DIR}/inventory.ini"

  if $all_ready; then
    echo "✓ All nodes are SSH-ready!"
    return 0
  else
    echo "✗ Some nodes not ready yet"
    return 1
  fi
}

# Wait for all nodes to be SSH-ready
ssh_attempt=1
while [ $ssh_attempt -le $MAX_SSH_RETRIES ]; do
  if check_all_ssh $ssh_attempt; then
    echo ""
    echo "=== SSH Readiness Check Completed Successfully! ==="
    echo "All cluster nodes are accessible via SSH."
    echo ""
    echo "You can now proceed with platform deployment:"
    echo "  make platform"
    exit 0
  fi

  if [ $ssh_attempt -lt $MAX_SSH_RETRIES ]; then
    echo "Waiting $SSH_RETRY_DELAY seconds before next SSH check..."
    sleep $SSH_RETRY_DELAY
  fi

  ssh_attempt=$((ssh_attempt + 1))
done

echo ""
echo "❌ Failed to establish SSH connectivity to all nodes after $MAX_SSH_RETRIES attempts"
echo "This may indicate infrastructure deployment issues."
echo ""
echo "Troubleshooting steps:"
echo "  • Check WireGuard connection: make wg"
echo "  • Verify infrastructure status: make address"
echo "  • Test basic connectivity: make ping"
exit 1