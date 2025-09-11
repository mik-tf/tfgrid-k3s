.PHONY: all infrastructure platform app clean wireguard dns ping help permissions connect

# Default target
all: infrastructure platform app

# Deploy infrastructure only (ThreeFold Grid VMs)
infrastructure:
	cd scripts && bash infrastructure.sh

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

# Set up wireguard connection
wireguard:
	cd scripts && bash wg.sh

# Configure DNS settings
dns:
	cd scripts && bash configure-dns.sh

# Ping nodes to check connectivity
ping:
	cd scripts && bash ping.sh

# Check cluster permissions
permissions:
	@echo "Checking cluster permissions..."
	@chmod +x scripts/cluster_permissions.sh
	@KUBECONFIG=$(CURDIR)/k3s.yaml ./scripts/cluster_permissions.sh

# Help information
help:
	@echo "TFGrid K3s Makefile Targets:"
	@echo "  make                - Run the complete deployment (infrastructure + platform + app)"
	@echo "  make all            - Same as 'make'"
	@echo "  make infrastructure - Deploy only ThreeFold Grid infrastructure"
	@echo "  make platform       - Deploy only K3s platform on existing infrastructure"
	@echo "  make app            - Deploy applications on existing platform"
	@echo "  make clean          - Clean up and destroy Terraform/OpenTofu resources"
	@echo "  make wireguard      - Set up the WireGuard connection"
	@echo "  make dns            - Configure DNS settings"
	@echo "  make ping           - Ping nodes to check connectivity"
	@echo "  make connect        - SSH into the management node"
	@echo "  make permissions    - Check cluster permissions"
	@echo "  make k9s            - Connect to management node and see K9s TUI"
