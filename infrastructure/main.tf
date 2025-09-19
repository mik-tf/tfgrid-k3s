terraform {
  required_providers {
    grid = {
      source = "threefoldtech/grid"
    }
  }
}

# Variables
variable "mnemonic" {
  type        = string
  sensitive   = true
  description = "ThreeFold mnemonic for authentication"
}
variable "SSH_KEY" {
  type        = string
  default     = null
  description = "SSH public key content (if null, will use ~/.ssh/id_ed25519.pub)"
}
variable "control_nodes" { type = list(number) } # e.g. [6905, 6906, 6907]
variable "worker_nodes" { type = list(number) }  # e.g. [6910, 6911, 6912]
variable "control_cpu" { type = number }
variable "control_mem" { type = number }
variable "control_disk" { type = number }
variable "worker_cpu" { type = number }
variable "worker_mem" { type = number }
variable "worker_disk" { type = number }

variable "network_name" {
  type        = string
  default     = "k3s_cluster_net"
  description = "Name of the network for the cluster"
}

variable "tfgrid_network" {
  type        = string
  default     = "main"
  description = "ThreeFold Grid network (main or test)"
}

variable "worker_public_ipv4" {
  type        = bool
  default     = true
  description = "Whether worker nodes should get public IPv4 addresses"
}

# Management node variables
variable "management_node" { type = number } # Single node ID for management
variable "management_cpu" {
  type    = number
  default = 1
}
variable "management_mem" {
  type    = number
  default = 2048 # 2GB RAM
}
variable "management_disk" {
  type    = number
  default = 25 # 25GB SSD
}

provider "grid" {
  mnemonic  = var.mnemonic
  network   = var.tfgrid_network
  relay_url = var.tfgrid_network == "main" ? "wss://relay.grid.tf" : "wss://relay.test.grid.tf"
}

# Generate unique mycelium keys/seeds for all nodes
locals {
  cluster_nodes = concat(var.control_nodes, var.worker_nodes)
  all_nodes     = concat([var.management_node], local.cluster_nodes)
}

resource "random_bytes" "k3s_mycelium_key" {
  for_each = toset([for n in local.cluster_nodes : tostring(n)]) # Convert numbers to strings
  length   = 32
}

resource "random_bytes" "k3s_ip_seed" {
  for_each = toset([for n in local.cluster_nodes : tostring(n)]) # Convert numbers to strings
  length   = 6
}

# Generate unique mycelium keys for management node
resource "random_bytes" "mgmt_mycelium_key" {
  length = 32
}

resource "random_bytes" "mgmt_ip_seed" {
  length = 6
}

# Mycelium overlay network
resource "grid_network" "k3s_network" {
  name          = var.network_name
  nodes         = local.all_nodes
  ip_range      = "10.1.0.0/16"
  add_wg_access = true
  mycelium_keys = merge(
    {
      for node in local.cluster_nodes : tostring(node) => random_bytes.k3s_mycelium_key[tostring(node)].hex
    },
    {
      tostring(var.management_node) = random_bytes.mgmt_mycelium_key.hex
    }
  )
}

# Unified node deployment for cluster nodes
resource "grid_deployment" "k3s_nodes" {
  for_each = {
    for idx, node in local.cluster_nodes :
    "node_${idx}" => {
      node_id    = node
      is_control = contains(var.control_nodes, node)
    }
  }

  node         = each.value.node_id
  network_name = grid_network.k3s_network.name

  disks {
    name = "disk_${each.key}"
    size = each.value.is_control ? var.control_disk : var.worker_disk
  }

  vms {
    name             = "vm_${each.key}"
    flist            = "https://hub.grid.tf/tf-official-vms/ubuntu-24.04-full.flist"
    cpu              = each.value.is_control ? var.control_cpu : var.worker_cpu
    memory           = each.value.is_control ? var.control_mem : var.worker_mem
    entrypoint       = "/sbin/zinit init"
    publicip         = !each.value.is_control && var.worker_public_ipv4
    mycelium_ip_seed = random_bytes.k3s_ip_seed[tostring(each.value.node_id)].hex # Convert to string

    env_vars = {
      SSH_KEY = var.SSH_KEY != null ? var.SSH_KEY : (
        fileexists(pathexpand("~/.ssh/id_ed25519.pub")) ?
        file(pathexpand("~/.ssh/id_ed25519.pub")) :
        file(pathexpand("~/.ssh/id_rsa.pub"))
      )
    }

    mounts {
      name        = "disk_${each.key}"
      mount_point = "/data"
    }
    rootfs_size = 20480
  }
}

# Management node deployment
resource "grid_deployment" "management_node" {
  node         = var.management_node
  network_name = grid_network.k3s_network.name

  disks {
    name = "disk_mgmt"
    size = var.management_disk
  }

  vms {
    name             = "vm_management"
    flist            = "https://hub.grid.tf/tf-official-vms/ubuntu-24.04-full.flist"
    cpu              = var.management_cpu
    memory           = var.management_mem
    entrypoint       = "/sbin/zinit init"
    publicip         = false
    mycelium_ip_seed = random_bytes.mgmt_ip_seed.hex

    env_vars = {
      SSH_KEY = var.SSH_KEY != null ? var.SSH_KEY : (
        fileexists(pathexpand("~/.ssh/id_ed25519.pub")) ?
        file(pathexpand("~/.ssh/id_ed25519.pub")) :
        file(pathexpand("~/.ssh/id_rsa.pub"))
      )
    }

    mounts {
      name        = "disk_mgmt"
      mount_point = "/data"
    }
    rootfs_size = 10240
  }
}

# Original cluster node outputs
output "wireguard_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes :
    key => dep.vms[0].ip
  }
}

output "mycelium_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes :
    key => dep.vms[0].mycelium_ip
  }
}

output "worker_public_ips" {
  value = {
    for key, dep in grid_deployment.k3s_nodes :
    key => dep.vms[0].computedip if contains(var.worker_nodes, dep.node)
  }
}

output "wg_config" {
  value = grid_network.k3s_network.access_wg_config
}

output "management_mycelium_ip" {
  value       = grid_deployment.management_node.vms[0].mycelium_ip
  description = "Mycelium IP of the management node"
}

output "management_node_wireguard_ip" {
  value       = grid_deployment.management_node.vms[0].ip
  description = "WireGuard IP of the management node"
}
