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

echo -e "${GREEN}TFGrid K3s Cluster Node Addresses${NC}"
echo "================================"
echo ""

cd "$INFRASTRUCTURE_DIR"

# Check if terraform/tofu is available
if command -v tofu &> /dev/null; then
    TERRAFORM_CMD="tofu"
elif command -v terraform &> /dev/null; then
    TERRAFORM_CMD="terraform"
else
    echo -e "${RED}ERROR: Neither OpenTofu nor Terraform found${NC}"
    exit 1
fi

# Get all IP addresses from Terraform outputs
MANAGEMENT_WG_IP=$($TERRAFORM_CMD output -raw management_node_wireguard_ip 2>/dev/null || echo "N/A")
WIREGUARD_IPS=$($TERRAFORM_CMD output -json wireguard_ips 2>/dev/null || echo "{}")
MYCELIUM_IPS=$($TERRAFORM_CMD output -json mycelium_ips 2>/dev/null || echo "{}")
WORKER_PUBLIC_IPS=$($TERRAFORM_CMD output -json worker_public_ips 2>/dev/null || echo "{}")

echo -e "${YELLOW}🔧 Management Node:${NC}"
if [ "$MANAGEMENT_WG_IP" != "N/A" ] && [ "$MANAGEMENT_WG_IP" != "null" ]; then
    echo "  WireGuard IP: $MANAGEMENT_WG_IP"
else
    echo "  WireGuard IP: Not deployed yet (run: make infrastructure)"
fi

echo ""
echo -e "${YELLOW}🏗️ Control Plane Nodes:${NC}"
if [ "$WIREGUARD_IPS" != "{}" ]; then
    # Parse control nodes (first node in the cluster)
    CONTROL_IP=$(echo "$WIREGUARD_IPS" | jq -r '.node_0 // empty' 2>/dev/null || echo "")
    if [ -n "$CONTROL_IP" ] && [ "$CONTROL_IP" != "null" ]; then
        echo "  node1 (Control): $CONTROL_IP"
    fi
else
    echo "  Not deployed yet (run: make infrastructure)"
fi

echo ""
echo -e "${YELLOW}⚙️ Worker Nodes:${NC}"
if [ "$WIREGUARD_IPS" != "{}" ]; then
    # Parse worker nodes (remaining nodes)
    WORKER_COUNT=0
    for key in $(echo "$WIREGUARD_IPS" | jq -r 'keys[]' 2>/dev/null | sort); do
        if [[ $key == node_* ]]; then
            node_index=$(echo "$key" | sed 's/node_//')
            if [ "$node_index" -gt 0 ]; then  # Skip node_0 (control plane)
                ip=$(echo "$WIREGUARD_IPS" | jq -r ".$key" 2>/dev/null || echo "")
                if [ -n "$ip" ] && [ "$ip" != "null" ]; then
                    node_num=$((node_index + 1))
                    echo "  node${node_num} (Worker): $ip"
                    WORKER_COUNT=$((WORKER_COUNT + 1))
                fi
            fi
        fi
    done
    if [ "$WORKER_COUNT" -eq 0 ]; then
        echo "  No worker nodes configured"
    fi
else
    echo "  Not deployed yet (run: make infrastructure)"
fi

echo ""
echo -e "${YELLOW}🌍 Mycelium IPv6 Addresses:${NC}"
if [ "$MYCELIUM_IPS" != "{}" ]; then
    echo "  Management: $($TERRAFORM_CMD output -raw management_mycelium_ip 2>/dev/null || echo "N/A")"
    for key in $(echo "$MYCELIUM_IPS" | jq -r 'keys[]' 2>/dev/null | sort); do
        if [[ $key == node_* ]]; then
            ip=$(echo "$MYCELIUM_IPS" | jq -r ".$key" 2>/dev/null || echo "")
            if [ -n "$ip" ] && [ "$ip" != "null" ]; then
                node_index=$(echo "$key" | sed 's/node_//')
                node_num=$((node_index + 1))
                node_type=$([ "$node_index" -eq 0 ] && echo "Control" || echo "Worker")
                echo "  node${node_num} ($node_type): $ip"
            fi
        fi
    done
else
    echo "  Not assigned yet"
fi

echo ""
echo -e "${YELLOW}🌐 Public IPv4 Addresses (Workers):${NC}"
if [ "$WORKER_PUBLIC_IPS" != "{}" ]; then
    PUBLIC_FOUND=false
    for key in $(echo "$WORKER_PUBLIC_IPS" | jq -r 'keys[]' 2>/dev/null | sort); do
        if [[ $key == node_* ]]; then
            ip=$(echo "$WORKER_PUBLIC_IPS" | jq -r ".$key" 2>/dev/null || echo "")
            if [ -n "$ip" ] && [ "$ip" != "null" ]; then
                node_index=$(echo "$key" | sed 's/node_//')
                node_num=$((node_index + 1))
                echo "  node${node_num} (Worker): $ip"
                PUBLIC_FOUND=true
            fi
        fi
    done
    if [ "$PUBLIC_FOUND" = false ]; then
        echo "  No public IPs assigned to workers"
    fi
else
    echo "  Not assigned yet"
fi

echo ""
echo -e "${YELLOW}💡 Usage Tips:${NC}"
echo "  • Use 'make wg' to connect to private networks"
echo "  • Use 'make ping' to test connectivity to nodes"
echo "  • Public websites work without WireGuard"
echo "  • SSH to private IPs requires WireGuard tunnel"
echo "  • Mycelium provides decentralized networking"

echo ""
echo -e "${YELLOW}🚀 Quick Commands:${NC}"
echo "  make wg        # Connect to private networks"
echo "  make ping      # Test node connectivity"
echo "  make platform  # Deploy K3s cluster"
echo "  make app       # Deploy applications"

echo ""
echo -e "${GREEN}Address information display completed${NC}"