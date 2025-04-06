#!/bin/bash

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=== Cluster Permissions Check ==="

check_permission() {
  local verb=$1
  local resource=$2
  local namespace=${3:-}
  local is_wildcard=false
  
  # Check if this is the wildcard permission check
  if [ "$verb" = "*" ] && [ "$resource" = "*" ]; then
    is_wildcard=true
  fi
  
  local cmd="kubectl auth can-i $verb $resource ${namespace:+--namespace=$namespace}"
  if $cmd >/dev/null 2>&1; then
    printf "${GREEN}✓${NC} %-40s [Allowed]\n" "$verb $resource${namespace:+ in $namespace}"
    if $is_wildcard; then
      echo -e "   ${RED}WARNING:${NC} Having wildcard permissions grants unrestricted access and is not recommended"
    fi
  else
    printf "${RED}✗${NC} %-40s [Denied]\n" "$verb $resource${namespace:+ in $namespace}"
    if $is_wildcard; then
      echo -e "   ${GREEN}NOTE:${NC} Not having wildcard permissions is expected and follows security best practices"
    fi
  fi
}

# Basic view permissions
check_permission get nodes
check_permission get pods --all-namespaces

# Service creation permissions
check_permission create services
check_permission create services default

# Other resource permissions
check_permission create deployments
check_permission create namespaces
check_permission delete pods

# Cluster-admin level (wildcard permissions check)
echo -e "\nChecking wildcard permissions (should normally be denied):"
check_permission '*' '*'

# RBAC permissions
check_permission create roles
check_permission create clusterroles
check_permission create rolebindings
check_permission create clusterrolebindings

echo -e "\n=== Check complete ==="
