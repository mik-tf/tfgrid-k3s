# K3s Cluster Deployment on ThreeFold Grid

A complete solution for deploying a K3s Kubernetes cluster on ThreeFold Grid using Terraform/OpenTofu for infrastructure provisioning and Ansible for configuration management, with a dedicated management node equipped with K9s as a terminal user interface.

## Overview

This repository combines infrastructure provisioning via Terraform/OpenTofu with automated K3s cluster configuration using Ansible. The entire deployment process is automated through a single command, creating both the cluster nodes and a dedicated management node.

### Features

- **Dedicated Management Node**: A VM on ThreeFold Grid for managing your cluster
- **Infrastructure as Code**: Provisions all necessary infrastructure using Terraform/OpenTofu
- **Lightweight Kubernetes**: Uses K3s instead of full Kubernetes
- **Fully Automated**: Single command deployment with `make`
- **WireGuard Integration**: Secure network connectivity between nodes
- **Mycelium Integration**: IPv6 overlay network installed on all nodes
- **High Availability**: Support for HA cluster deployment
- **Scalable**: Support for multiple worker nodes
- **Ready for Apps**: Pre-configured for deploying your applications

## Architecture

The deployment consists of:

1. **Control Plane Nodes**: Run the Kubernetes control plane components (`k3s_control` group)
2. **Worker Nodes**: Run application workloads (`k3s_worker` group)
3. **Management Node**: Dedicated node for cluster management with all required tools (`k3s_management` group)

The management node lives within the same private network as your cluster nodes, providing secure management without exposing your cluster to the public internet.

## Kubernetes Components

The K3s cluster is deployed with the following components for full functionality:

### Core Components
- **K3s**: Lightweight Kubernetes distribution with built-in components disabled (Traefik, ServiceLB)
- **Flannel**: CNI plugin for pod networking using VXLAN backend

### Load Balancing & Ingress
- **MetalLB**: Load balancer for Kubernetes services, providing external IP addresses
- **Nginx Ingress Controller**: Ingress controller for routing external traffic to services

### Networking Configuration

The cluster automatically adapts its networking based on your `MAIN_NETWORK` setting:

#### WireGuard Network (IPv4)
- **K3s Configuration**: Standard IPv4 networking
- **MetalLB**: Configures IPv4 address pools (`/32` subnets)
- **Nginx Ingress**: Uses IPv4-compatible deployment manifest
- **IP Addresses**: 10.x.x.x range for cluster communication

#### Mycelium Network (IPv6)
- **K3s Configuration**: Dual-stack IPv4/IPv6 networking enabled
- **MetalLB**: Configures IPv6 address pools (`/128` subnets)
- **Nginx Ingress**: Modified deployment manifest with IPv6 support
- **IP Addresses**: IPv6 addresses for cluster communication

This ensures Nginx and all cluster services work correctly regardless of your chosen network type.

> Note: The code is tested and fully functional with WireGuard. There might be issues with Mycelium until it is fully tested. This documentation will be updated when this happens.

## Prerequisites

- Linux/macOS system with bash
- [OpenTofu](https://opentofu.org/) (or Terraform) installed
- [Ansible](https://www.ansible.com/) installed
- [WireGuard](https://www.wireguard.com/) installed
- [jq](https://stedolan.github.io/jq/) installed
- ThreeFold account with sufficient TFT balance

## Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/mik-tf/tfgrid-k3s
   cd tfgrid-k3s
   ```

2. Configure your deployment:
   ```bash
   # Set up Terraform/OpenTofu configuration for non-sensitive settings
   cp infrastructure/credentials.auto.tfvars.example infrastructure/credentials.auto.tfvars
   nano infrastructure/credentials.auto.tfvars

   # MAXIMUM SECURITY: Set up your ThreeFold mnemonic securely (prevents shell history recording)
   set +o history
   export TF_VAR_mnemonic="your_actual_mnemonic_phrase"
   set -o history
   ```

   See `docs/security.md` for more details on secure credential handling.

   > **SSH Key Auto-Detection**: The system will automatically use your SSH keys for deployment without requiring manual configuration. It first checks for `~/.ssh/id_ed25519.pub`, then falls back to `~/.ssh/id_rsa.pub` if needed. You can also manually specify your SSH key in the `credentials.auto.tfvars` file if desired.

3. Deploy the cluster:

    ```bash
    # Complete deployment (infrastructure, platform, applications)
    make deploy

    # Or deploy step by step:
    make infrastructure   # Deploy ThreeFold Grid VMs
    make inventory        # Generate Ansible inventory
    make wg               # Setup WireGuard connection
    make platform         # Configure K3s on the infrastructure
    make app              # Deploy applications on the K3s cluster

    # Quick redeployment (assumes infrastructure exists)
    make quick
    ```

    > **Tip**: Run `make help` to see all available commands

3. Configure network connectivity (optional):
   ```bash
   # Copy environment configuration
   cp .env.example .env

   # Choose network for Ansible connectivity (wireguard or mycelium)
   # Edit .env file to set MAIN_NETWORK=wireguard or MAIN_NETWORK=mycelium
   # This setting also affects make connect, make ping, and make k9s commands
   nano .env
   ```

4. After deployment, for security, unset the sensitive environment variable:
   ```bash
   unset TF_VAR_mnemonic
   ```

## Deployment Process

The deployment happens in three distinct phases, which can be run individually or together:

### 1. Infrastructure Deployment (`make infrastructure`)

Runs `scripts/infrastructure.sh`, which:
- Cleans up any previous infrastructure
- Initializes and applies Terraform/OpenTofu configuration
- Sets up WireGuard connections
- Generates the Ansible inventory based on deployed nodes
- Tests connectivity to all nodes

### 2. Platform Deployment (`make platform`)

Runs `scripts/platform.sh`, which:
- **Automatically waits for SSH availability** on all nodes before proceeding (eliminates timing issues)
- Configures the management node with required tools (Ansible, kubectl, Helm)
- Deploys the K3s control plane on the `k3s_control` nodes
- Joins worker nodes to the cluster
- Sets up kubectl configuration for easy access

### 3. Application Deployment (`make app`)

Runs `scripts/app.sh`, which:
- Verifies the cluster is ready
- Deploys your applications (customizable)

## Using the Management Node

The management node is your central location for all cluster operations. After deployment completes, you'll receive the management node's IP address.

### Connecting to the Management Node

```bash
# Connect to the management node (uses network configured in .env)
make connect

# Or directly:
ssh root@<management-node-ip>

# Connect to the management node and launch K9s TUI directly (uses configured network)
make k9s
```

### Managing Your Cluster from the Management Node

Once connected to the management node, you can:

```bash
# Check cluster status
kubectl get nodes

# View running pods
kubectl get pods -A

# Run Helm commands
helm list -A

# Launch K9s Terminal UI for Kubernetes
k9s

# Update cluster configuration
cd ~/tfgrid-k3s/platform
ansible-playbook site.yml
```

The management node has all necessary tools pre-installed:
- kubectl
- K9s
- Ansible
- Helm
- OpenTofu
- WireGuard

## Additional Management Commands

```bash
# Show cluster node addresses and access information
make address

# Check connectivity to all nodes (uses configured network)
make ping

# Check SSH readiness of all cluster nodes
make ready

# Connect to the management node (uses configured network)
make connect

# Connect to management node and launch K9s TUI (uses configured network)
make k9s

# Verify cluster permissions
make permissions

# Configure DNS settings
make dns

# Clean up deployment resources
make clean
```

**Note**: `make connect`, `make ping`, and `make k9s` automatically use the network configured in your `.env` file (`MAIN_NETWORK` setting).

Run `make help` for a complete list of available commands.

## Project Structure

```
tfgrid_k3s/
├── infrastructure/    # Infrastructure provisioning (via OpenTofu)
│   ├── credentials.auto.tfvars.example  # Example configuration variables (non-sensitive)
│   └── main.tf        # Main infrastructure definition with secure variable handling
├── platform/          # Platform configuration and K3s deployment (via Ansible)
│   ├── roles/         # Configuration components
│   │   ├── common/    # Common configuration for all nodes
│   │   ├── control/   # K3s control plane configuration
│   │   ├── worker/    # K3s worker node configuration
│   │   ├── management/ # Management node configuration
│   │   └── kubeconfig/# kubectl configuration
│   └── site.yml       # Main deployment playbook
├── scripts/           # Deployment and utility scripts
│   ├── infrastructure.sh # Script to deploy infrastructure
│   ├── platform.sh    # Script to deploy platform
│   ├── app.sh         # Script to deploy applications
│   ├── cleantf.sh     # Script to clean Terraform/OpenTofu state
│   ├── ping.sh        # Connectivity test utility
│   └── wg.sh          # WireGuard setup script
├── Makefile           # Main interface for all deployment commands
└── docs/              # Additional documentation
    ├── security.md    # Security best practices documentation
    └── troubleshooting.md # Solutions to common issues
    └── k9s.md         # K9s documentation
```

## Infrastructure Configuration

In your `credentials.auto.tfvars` file, you can configure:

```
# Management node specifications (defaults if not specified)
# management_cpu = 1      # 1 vCPU
# management_mem = 2048   # 2GB RAM
# management_disk = 25    # 25GB storage

# Optional: Set to false to deploy worker nodes without public IPv4 addresses
# worker_public_ipv4 = true  # Default is true

# Node IDs from ThreeFold Grid
control_nodes = [1000, 1001, 1002]  # Control plane node IDs
worker_nodes = [2000, 2001, 2002]   # Worker node IDs
management_node = 3000              # Management node ID

# Control plane node specifications
control_cpu = 4
control_mem = 8192   # 8GB RAM
control_disk = 100   # 100GB storage

# Worker node specifications
worker_cpu = 8
worker_mem = 16384   # 16GB RAM
worker_disk = 250    # 250GB storage
```

## Network Configuration

The deployment supports two network options for Ansible connectivity. Your choice affects not just connectivity, but also how the Kubernetes cluster components (K3s, MetalLB, Nginx) are configured:

### WireGuard (Default, IPv4)
- **Type**: Private overlay network
- **IP Addresses**: IPv4 (10.x.x.x range)
- **Security**: Encrypted VPN connections
- **Use Case**: Most reliable for production deployments
- **Cluster Impact**: Standard IPv4-only Kubernetes networking

### Mycelium (IPv6)
- **Type**: Decentralized IPv6 overlay network
- **IP Addresses**: IPv6 addresses
- **Security**: Built-in encryption
- **Use Case**: Alternative when WireGuard has issues
- **Cluster Impact**: Dual-stack IPv4/IPv6 Kubernetes networking with IPv6-optimized components

### Switching Networks

To change the network used for Ansible connectivity and management commands:

1. Edit your `.env` file:
    ```bash
    # For WireGuard (default)
    MAIN_NETWORK=wireguard

    # For Mycelium
    MAIN_NETWORK=mycelium
    ```

2. Regenerate the inventory:
    ```bash
    make inventory
    ```

3. Re-run the platform deployment:
    ```bash
    make platform
    ```

**Important**: After switching networks, all management commands automatically use the configured network:

- `make connect` - Connects to management node via the configured network
- `make ping` - Tests connectivity using the configured network's IPs
- `make k9s` - Connects and launches K9s via the configured network

Both networks are always available on all nodes, so you can switch between them if one has connectivity issues. The system will automatically configure K3s, MetalLB, and Nginx appropriately based on your `MAIN_NETWORK` setting.

## Maintenance and Updates

### Updating Cluster Configuration

To update your cluster configuration, connect to the management node and run:

```bash
cd ~/tfgrid-k3s/platform
ansible-playbook site.yml
```

### Adding or Removing Nodes

To add or remove nodes:

1. Update your `credentials.auto.tfvars` file
2. Run `make infrastructure` again to update the infrastructure
3. Run `make platform` to reconfigure the cluster

## Troubleshooting

See the [troubleshooting guide](docs/troubleshooting.md) for common issues and solutions.

### Common Issues

#### Management Node Connection Issues

If you can't connect to the management node:

1. Verify the node has been deployed correctly:
   ```bash
   cd infrastructure
   tofu output management_node_wireguard_ip
   ```

2. Check WireGuard connection status:
   ```bash
   sudo wg show
   ```

#### Kubernetes Access Issues

If you can connect to the management node but can't access the cluster:

1. Check if kubectl is configured:
   ```bash
   kubectl cluster-info
   ```

2. Verify the cluster nodes are running:
   ```bash
   kubectl get nodes
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
