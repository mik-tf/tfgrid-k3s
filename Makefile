.PHONY: deploy clean wireguard dns ping help permissions

# Default target
all: deploy

# Primary target to deploy the K3s cluster
deploy:
	cd scripts && bash deploy.sh

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
	@./scripts/cluster_permissions.sh

# Help information
help:
	@echo "TFGrid K3s Makefile Targets:"
	@echo "  make         - Run the default deployment (same as 'make deploy')"
	@echo "  make deploy  - Deploy the K3s cluster on ThreeFold Grid"
	@echo "  make clean   - Clean up and destroy Terraform/OpenTofu resources"
	@echo "  make wireguard - Set up the WireGuard connection"
	@echo "  make dns     - Configure DNS settings"
	@echo "  make ping    - Ping nodes to check connectivity"
	@echo "  make permissions - Check cluster permissions"
