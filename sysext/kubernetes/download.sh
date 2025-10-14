#!/bin/bash

set -euo pipefail

# Source all include files using wildcard
for script in "${BASH_SOURCE[0]%/*}/common.d"/*.sh; do
	[[ -f ${script} ]] && source "${script}"
done

for script in "${BASH_SOURCE[0]%/*}/apps.d"/*.sh; do
	[[ -f ${script} ]] && source "${script}"
done

# Load configuration
load_config

# Derived paths
BIN_DIR="${SYSEXT_OVERLAY_DIR}/usr/bin"
OPT_BIN_DIR="${SYSEXT_OVERLAY_DIR}/opt/bin"
KUBERNETES_BIN_DIR="${SYSEXT_OVERLAY_DIR}/opt/kubernetes/bin"
VERSION_DIR="${SYSEXT_OVERLAY_DIR}"

# Main function
main()
{
	map_architecture
	ensure_directories

	log_info "Starting binary downloads based on configuration..."

	# Kubernetes core components
	download_kubeadm
	download_kubectl
	download_kubelet
	download_kube_apiserver
	download_kube_controller_manager
	download_kube_scheduler

	# Container runtimes
	download_containerd
	download_runc
	download_crictl

	# Networking tools
	download_cilium
	download_cni_plugins

	# Datastore
	download_etcd

	# Utility tools
	download_jq
	download_yq
	download_envsubst

	# Cluster management tools
	download_clusterctl
	download_helm

	# Additional tools
	download_oras
	download_krew

	log_info "Download process completed"
}

# Run main function
main "$@"
