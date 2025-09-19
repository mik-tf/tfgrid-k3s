.PHONY: all deploy quick infrastructure inventory platform app clean wg dns ping ready help permissions connect

# Default target - complete deployment
all: deploy

# Main deployment workflow
deploy: infrastructure inventory wg platform app
	@echo "🎉 K3s cluster deployment completed successfully!"

# Quick redeployment (assumes infrastructure exists)
quick: inventory wg platform app
	@echo "⚡ Quick K3s redeployment completed!"

# Deploy infrastructure only (ThreeFold Grid VMs)
infrastructure:
	cd scripts && bash infrastructure.sh

# Generate Ansible inventory from Terraform outputs
inventory:
	@echo "📋 Generating Ansible inventory..."
	@./scripts/generate-inventory.sh

# Show cluster node addresses and access information
address:
	@echo "📍 TFGrid K3s Cluster Node Addresses..."
	@cd scripts && bash address.sh

# Deploy platform only (K3s cluster)
platform:
	cd scripts && bash platform.sh

# Deploy applications
app:
	cd scripts && bash app.sh

# Connect to management node
connect:
	cd scripts && bash connect-management.sh

# Connect to management node and see K9s TUI
k9s:
	cd scripts && bash k9s.sh

# Clean up Terraform/OpenTofu resources
clean:
	cd scripts && bash cleantf.sh

# Set up WireGuard connection
wg:
	cd scripts && bash wg.sh

# Configure DNS settings
dns:
	cd scripts && bash configure-dns.sh

# Ping nodes to check connectivity
ping:
	cd scripts && bash ping.sh

# Check SSH readiness of all nodes
ready:
	@echo "🔧 Checking SSH readiness of all cluster nodes..."
	@cd scripts && bash ready.sh

# Check cluster permissions
permissions:
	@echo "Checking cluster permissions..."
	@chmod +x scripts/cluster_permissions.sh
	@KUBECONFIG=$(CURDIR)/k3s.yaml ./scripts/cluster_permissions.sh

# Help message
help:
	@echo "🚀 TFGrid K3s Cluster Deployment"
	@echo "==============================="
	@echo ""
	@echo "🎯 Main Commands:"
	@echo "  make all            - Complete K3s cluster deployment (default)"
	@echo "  make deploy         - Deploy complete K3s cluster to ThreeFold Grid"
	@echo "  make quick          - Quick redeployment (assumes infrastructure exists)"
	@echo "  make infrastructure - Deploy ThreeFold Grid infrastructure only"
	@echo "  make inventory      - Generate Ansible inventory from infrastructure"
	@echo "  make wg             - Setup WireGuard connection to cluster"
	@echo "  make platform       - Deploy K3s platform on existing infrastructure"
	@echo "  make app            - Deploy applications on existing platform"
	@echo "  make clean          - Clean up all ThreeFold Grid resources"
	@echo ""
	@echo "🔧 Development & Testing Commands:"
	@echo "  make address        - Show cluster node addresses and access info"
	@echo "  make ping           - Test connectivity to all cluster nodes"
	@echo "  make ready          - Check SSH readiness of all cluster nodes"
	@echo "  make connect        - SSH into the management node"
	@echo "  make k9s            - Connect to management node and open K9s TUI"
	@echo "  make permissions    - Check cluster permissions"
	@echo "  make dns            - Configure DNS settings"
	@echo ""
	@echo "📋 Configuration:"
	@echo "  1. Copy infrastructure/credentials.auto.tfvars.example to infrastructure/credentials.auto.tfvars"
	@echo "  2. Edit infrastructure/credentials.auto.tfvars with your node IDs"
	@echo "  3. Copy .env.example to .env and configure network (optional, defaults to wireguard)"
	@echo "  4. Set TF_VAR_mnemonic environment variable with your ThreeFold mnemonic"
	@echo "  5. Run: make deploy"
	@echo ""
	@echo "🌐 Environment Variables:"
	@echo "  TF_VAR_mnemonic     - ThreeFold mnemonic (required)"
	@echo "  TF_VAR_tfgrid_network - Network to deploy on (main/test, default: test)"
	@echo ""
	@echo "🎯 Quick Start:"
	@echo "  export TF_VAR_mnemonic=\"your twelve word mnemonic here\""
	@echo "  make deploy"
	@echo ""
	@echo "📋 For existing infrastructure:"
	@echo "  make quick"
	@echo ""
	@echo "📊 Cluster Architecture:"
	@echo "  • 1 Management Node (monitoring, tools)"
	@echo "  • 1 Control Plane Node (K3s master)"
	@echo "  • 2+ Worker Nodes (application workloads)"
	@echo ""
	@echo "🔗 Networking:"
	@echo "  • WireGuard: Private overlay network"
	@echo "  • Mycelium: Decentralized IPv6 networking"
	@echo "  • Public IPs: Available for worker nodes (optional)"
