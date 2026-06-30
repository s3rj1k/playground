#!/bin/bash
#
# Local Path Provisioner installation script
# Installs Rancher Local Path Provisioner for local storage
#

set -euo pipefail

# Set environment variables
export KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

echo "Installing Local Path Provisioner..."

# Get latest version from GitHub API
echo "Fetching latest Local Path Provisioner version..."
VERSION=$(curl -s "https://api.github.com/repos/rancher/local-path-provisioner/releases/latest" |
	grep '"tag_name":' |
	sed -E 's/.*"([^"]+)".*/\1/')
if [[ -z $VERSION ]]; then
	echo "Error: Failed to fetch Local Path Provisioner version"
	exit 1
fi

echo "Local Path Provisioner version: $VERSION"

# Apply Local Path Provisioner manifest
echo "Applying Local Path Provisioner manifest..."
RETRIES=5
DELAY=30

for i in $(seq 1 $RETRIES); do
	if kubectl apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/$VERSION/deploy/local-path-storage.yaml"; then
		echo "Local Path Provisioner manifest applied successfully"
		break
	elif [[ $i -eq $RETRIES ]]; then
		echo "Error: Failed to apply Local Path Provisioner manifest after $RETRIES attempts"
		exit 1
	else
		echo "Attempt $i failed, retrying in ${DELAY}s..."
		sleep $DELAY
	fi
done

# Wait for deployment to be ready
echo "Waiting for Local Path Provisioner deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/local-path-provisioner -n local-path-storage

# Set Local Path Storage as default storage class
echo "Setting Local Path Storage as default storage class..."
for i in $(seq 1 $RETRIES); do
	if kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'; then
		echo "Local Path Storage set as default storage class successfully"
		break
	elif [[ $i -eq $RETRIES ]]; then
		echo "Error: Failed to set default storage class after $RETRIES attempts"
		exit 1
	else
		echo "Attempt $i failed, retrying in ${DELAY}s..."
		sleep $DELAY
	fi
done

echo "Local Path Provisioner installation completed successfully!"

# Show storage classes
echo "Available storage classes:"
kubectl get storageclass
