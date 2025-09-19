#!/bin/bash
# Remove set -e to allow the script to handle failures and retries
# set -e

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PLATFORM_DIR="$PROJECT_ROOT/platform"
INVENTORY_FILE="$PLATFORM_DIR/inventory.ini"

# Load environment configuration
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
else
    echo "Warning: .env file not found, using defaults"
    MAIN_NETWORK="${MAIN_NETWORK:-wireguard}"
fi

# Check if inventory exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Inventory file not found. Run generate-inventory.sh first."
    exit 1
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- Configuration ---
# Global script retry settings
MAX_SCRIPT_RETRIES=10
SCRIPT_RETRY_DELAY=30  # seconds between full script retries

# Individual host check settings (within a single script run)
MAX_HOST_RETRIES=3     # Retries for a single host within one script attempt
HOST_RETRY_DELAY=5     # seconds between checks for a single host
SSH_CONNECT_TIMEOUT=10 # SSH connection timeout (seconds)
# --- End Configuration ---

# Function to ping a host with retries (for a single host within a script run)
ping_host() {
    local user=$1
    local ip=$2
    local name=$3
    local host_retries=0 # Using a local counter for clarity

    echo -n "  Checking $name (${ip})... " # Slightly clearer message

    while [ $host_retries -lt $MAX_HOST_RETRIES ]; do # Use MAX_HOST_RETRIES
        # Use ping with timeout
        if ping -c 1 -W 5 "$ip" >/dev/null 2>&1; then
            echo -e "${GREEN}Success!${NC}"
            return 0 # Host reachable
        else
            host_retries=$((host_retries+1))

            if [ $host_retries -lt $MAX_HOST_RETRIES ]; then # Check against MAX_HOST_RETRIES
                # Clarify this is a host-level retry attempt
                echo -e "${YELLOW}Failed (host attempt $host_retries/$MAX_HOST_RETRIES)${NC}"
                echo -n "  Retrying $name in $HOST_RETRY_DELAY seconds... " # Use HOST_RETRY_DELAY
                sleep $HOST_RETRY_DELAY
                # Re-print the initial check line for clarity on retry
                echo -n "  Checking $name (${ip})... "
            else
                # Failed all host-level retries for *this* script run
                echo -e "${RED}Failed after $MAX_HOST_RETRIES attempts!${NC}" # Use MAX_HOST_RETRIES
                return 1 # Host unreachable for this script run
            fi
        fi
    done
    # Fallback return in case loop condition is met unexpectedly
    return 1
}

# Initialize global counters - THESE WILL BE RESET EACH SCRIPT ATTEMPT
total_success=0
total_failed=0

# Function to test nodes in a specific section
# This function modifies the global total_success and total_failed counters
test_nodes() {
    local section=$1
    local title=$2
    local section_success=0 # Counter for this section only
    local section_failed=0  # Counter for this section only

    echo -e "\n${BLUE}=== Testing $title Nodes ===${NC}"

    # Use the original inventory parsing logic
    local capture=0
    local nodes_lines=() # Store the raw lines matching the section

    while IFS= read -r line; do
        # Start capturing at section start
        if [[ "$line" == "[$section]" ]]; then
            capture=1
            continue
        fi
        # Stop at next section or end of relevant block
        if [[ $capture -eq 1 && "$line" =~ ^\s*\[ ]]; then
            capture=0
            # Don't 'continue' here, the line might be the start of the *next* section
        fi
        # Capture non-empty lines with ansible_host while capturing
        if [[ $capture -eq 1 && "$line" =~ ansible_host ]] && [[ -n "$line" ]] && [[ ! "$line" =~ ^\s*# ]]; then
             nodes_lines+=("$line")
        fi
    done < "$INVENTORY_FILE"

    # Count and display nodes found
    local count=${#nodes_lines[@]}
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}  No nodes found in [$section] section${NC}"
        return # Exit the function, no nodes to test
    fi

    echo -e "${CYAN}  Found $count $title node(s)${NC}"

    # Process each node line found
    for node_line in "${nodes_lines[@]}"; do
        # Use original parsing logic
        name=$(echo "$node_line" | awk '{print $1}')
        # Handle potential spacing issues with grep/cut
        ip=$(echo "$node_line" | grep -o "ansible_host=[^ ]*" | cut -d= -f2)
        user=$(echo "$node_line" | grep -o "ansible_user=[^ ]*" | cut -d= -f2)

        # Basic check if IP and User were extracted
        if [ -z "$ip" ] || [ -z "$user" ]; then
            echo -e "${YELLOW}  Warning: Could not parse IP or User for line: '$node_line' in section [$section]. Skipping.${NC}"
            section_failed=$((section_failed+1))
            total_failed=$((total_failed+1)) # Increment global counter
            continue
        fi

        if ping_host "$user" "$ip" "$name"; then
            section_success=$((section_success+1))
            total_success=$((total_success+1)) # Increment global counter
        else
            section_failed=$((section_failed+1))
            total_failed=$((total_failed+1))   # Increment global counter
        fi
    done

    # Section summary
    if [ $section_failed -eq 0 ]; then
        echo -e "${GREEN}  ✓ All $title nodes are reachable in this attempt ($section_success/$count)${NC}"
    else
        echo -e "${RED}  ✗ Some $title nodes unreachable in this attempt ($section_failed/$count failed)${NC}"
    fi
    # No return value needed as it modifies global counters
}


# --- Main Script Logic with Global Retries ---
echo -e "${GREEN}🔍 TFGrid K3s Cluster Connectivity Test${NC}"
echo "========================================"
echo "Network: ${MAIN_NETWORK:-wireguard}"
echo ""

# Check network connectivity based on MAIN_NETWORK setting
case "${MAIN_NETWORK:-wireguard}" in
    "wireguard")
        # Check if WireGuard is active
        if ! sudo wg show k3s >/dev/null 2>/dev/null; then
            echo -e "${RED}ERROR: WireGuard interface 'k3s' not found${NC}"
            echo "Run './scripts/wg.sh' or 'make wg' first to set up WireGuard"
            exit 1
        fi

        echo -e "${YELLOW}WireGuard interface status:${NC}"
        sudo wg show k3s
        echo ""
        ;;
    "mycelium")
        # For Mycelium, we don't need to check a specific interface
        # The mycelium network is decentralized and IPs are accessible directly
        echo -e "${YELLOW}Using Mycelium network for connectivity checks${NC}"
        echo ""
        ;;
    *)
        echo -e "${RED}ERROR: Invalid MAIN_NETWORK: ${MAIN_NETWORK}. Use 'wireguard' or 'mycelium'${NC}"
        exit 1
        ;;
esac

script_attempt=1
overall_success=0 # Flag to track if any attempt succeeded

while [ $script_attempt -le $MAX_SCRIPT_RETRIES ]; do
    echo -e "\n${CYAN}<<<<< Starting Check Attempt $script_attempt / $MAX_SCRIPT_RETRIES >>>>>${NC}"

    # RESET global counters for THIS attempt
    total_success=0
    total_failed=0
    found_any_nodes=0 # Track if we actually tested anything

    # --- Run the checks for all sections ---
    test_nodes "k3s_management" "Management"
    # Check if nodes were found in the previous call to update found_any_nodes
    [ $total_success -gt 0 ] || [ $total_failed -gt 0 ] && found_any_nodes=1

    test_nodes "k3s_control" "Control Plane"
    [ $total_success -gt 0 ] || [ $total_failed -gt 0 ] && found_any_nodes=1

    test_nodes "k3s_worker" "Worker"
    [ $total_success -gt 0 ] || [ $total_failed -gt 0 ] && found_any_nodes=1
    # --- End of checks for this attempt ---

    # Overall summary for *this attempt*
    echo -e "\n${BLUE}----- Attempt $script_attempt Summary -----${NC}"
    total_tested_this_run=$((total_success + total_failed))
    echo "Total nodes tested this attempt: $total_tested_this_run"
    echo "Reachable this attempt: $total_success"
    echo "Unreachable this attempt: $total_failed"

    # Check if this attempt was successful
    # Success means: no failures AND at least one node was tested (or no nodes found is also ok)
    if [ $total_failed -eq 0 ]; then
        if [ $total_tested_this_run -gt 0 ]; then
             echo -e "${GREEN}✓ Attempt $script_attempt SUCCEEDED. All tested nodes reachable.${NC}"
             overall_success=1
             break # Exit the while loop, we are done!
        else
             # Handle case where inventory sections might be empty
             if [ $found_any_nodes -eq 0 ]; then
                echo -e "${YELLOW}✓ Attempt $script_attempt completed. No nodes found to test in specified sections.${NC}"
                overall_success=1 # Consider it success if no nodes needed testing
                break
             else
                 # This case shouldn't happen if found_any_nodes logic is right, but included for safety
                 echo -e "${YELLOW}✓ Attempt $script_attempt completed. No failures, but unclear if nodes were tested.${NC}"
                 overall_success=1
                 break
             fi
        fi
    else
        # This attempt failed
        echo -e "${RED}✗ Attempt $script_attempt FAILED ($total_failed/$total_tested_this_run unreachable).${NC}"
        if [ $script_attempt -lt $MAX_SCRIPT_RETRIES ]; then
            echo -e "${YELLOW}Retrying entire check in $SCRIPT_RETRY_DELAY seconds...${NC}"
            sleep $SCRIPT_RETRY_DELAY
        else
            echo -e "${RED}Maximum script retries ($MAX_SCRIPT_RETRIES) reached.${NC}"
        fi
    fi

    script_attempt=$((script_attempt+1))
done

# --- Final Result ---
echo -e "\n${BLUE}====== Final Connectivity Check Result ======${NC}"
if [ $overall_success -eq 1 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED (within $MAX_SCRIPT_RETRIES attempts).${NC}"
    echo ""
    echo -e "${YELLOW}💡 Next Steps:${NC}"
    echo "  • Run 'make platform' to deploy K3s cluster"
    echo "  • Run 'make app' to deploy applications"
    echo "  • Run 'make connect' to SSH into management node"
    echo "  • Run 'make k9s' for cluster management TUI"
    exit 0
else
    echo -e "${RED}✗ CHECK FAILED: Some nodes remained unreachable after $MAX_SCRIPT_RETRIES attempts.${NC}"
    echo "  (Final attempt status: $total_failed/$total_tested_this_run unreachable)"
    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
    case "${MAIN_NETWORK:-wireguard}" in
        "wireguard")
            echo "  • Check WireGuard connection: make wg"
            ;;
        "mycelium")
            echo "  • Verify Mycelium network is running on nodes"
            ;;
    esac
    echo "  • Verify infrastructure deployment: make infrastructure"
    echo "  • Regenerate inventory: make inventory"
    echo "  • Check node addresses: make address"
    exit 1
fi
