Check connectivity

# Check basic view permissions
kubectl auth can-i get nodes
kubectl auth can-i get pods --all-namespaces

# Check service creation permissions
kubectl auth can-i create services
kubectl auth can-i create services --namespace=default

# Check other resource permissions
kubectl auth can-i create deployments
kubectl auth can-i create namespaces
kubectl auth can-i delete pods

# Check cluster-admin level permissions
kubectl auth can-i '*' '*'

# Check if user can create roles and cluster roles
kubectl auth can-i create roles
kubectl auth can-i create clusterroles

# Check if user can modify RBAC
kubectl auth can-i create rolebindings
kubectl auth can-i create clusterrolebindings