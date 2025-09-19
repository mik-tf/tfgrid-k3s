#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DIR="$SCRIPT_DIR/.."
INFRASTRUCTURE_DIR="$PROJECT_DIR/infrastructure"
PLATFORM_DIR="$PROJECT_DIR/platform"

echo -e "${GREEN}Cleaning up TFGrid K3s deployment${NC}"
echo "=================================="

# Check if tofu/terraform is available
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
elif command -v terraform &> /dev/null; then
    TERRAFORM_CMD="terraform"
else
    echo -e "${YELLOW}WARNING: Neither tofu nor terraform found. Skipping infrastructure destruction.${NC}"
    TERRAFORM_CMD=""
fi

if [[ -n "$TERRAFORM_CMD" ]]; then
    echo -e "${YELLOW}Destroying infrastructure with $TERRAFORM_CMD...${NC}"
    cd "$INFRASTRUCTURE_DIR"
    if $TERRAFORM_CMD destroy -auto-approve 2>/dev/null; then
        echo -e "${GREEN}✓ Infrastructure destroyed successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Infrastructure destruction failed or no resources to destroy${NC}"
    fi
    cd "$PROJECT_DIR"
fi

echo -e "${YELLOW}Removing Terraform and Ansible generated files...${NC}"

# Remove Terraform state files and Ansible generated files
FILES_TO_REMOVE=(
    "$INFRASTRUCTURE_DIR/terraform.tfstate"
    "$INFRASTRUCTURE_DIR/terraform.tfstate.backup"
    "$INFRASTRUCTURE_DIR/state.json"
    "$INFRASTRUCTURE_DIR/crash.log"
    "$INFRASTRUCTURE_DIR/.terraform.lock.hcl"
    "$PLATFORM_DIR/inventory.ini"
)

for file in "${FILES_TO_REMOVE[@]}"; do
    if [[ -f "$file" ]]; then
        rm -f "$file"
        echo -e "${GREEN}✓ Removed $file${NC}"
    fi
done

# Remove .terraform directory
if [[ -d "$INFRASTRUCTURE_DIR/.terraform" ]]; then
    rm -rf "$INFRASTRUCTURE_DIR/.terraform"
    echo -e "${GREEN}✓ Removed $INFRASTRUCTURE_DIR/.terraform directory${NC}"
fi

# Remove any .tfstate.* files
TFSTATE_FILES=$(find "$INFRASTRUCTURE_DIR" -name "*.tfstate.*" 2>/dev/null)
if [[ -n "$TFSTATE_FILES" ]]; then
    echo "$TFSTATE_FILES" | while read -r file; do
        rm -f "$file"
        echo -e "${GREEN}✓ Removed $file${NC}"
    done
fi

# Check and bring down WireGuard if it exists
if [[ -f "/etc/wireguard/k3s.conf" ]]; then
    echo -e "${YELLOW}Bringing down WireGuard interface...${NC}"
    if sudo wg-quick down k3s 2>/dev/null; then
        echo -e "${GREEN}✓ WireGuard interface brought down successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to bring down WireGuard with wg-quick. Trying alternative method...${NC}"
        if sudo ip link delete k3s 2>/dev/null; then
            echo -e "${GREEN}✓ WireGuard interface removed via ip link${NC}"
        else
            echo -e "${YELLOW}⚠ Could not remove WireGuard interface${NC}"
        fi
    fi
    if sudo rm -f /etc/wireguard/k3s.conf 2>/dev/null; then
        echo -e "${GREEN}✓ Removed WireGuard config file${NC}"
    else
        echo -e "${YELLOW}⚠ Could not remove WireGuard config file${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Cleanup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Note: This only removes local files and destroys cloud resources.${NC}"
echo -e "${YELLOW}Your source code and configuration files are preserved.${NC}"
