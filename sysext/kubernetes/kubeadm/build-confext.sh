#!/bin/bash

# https://uapi-group.org/specifications/specs/extension_image/

set -euo pipefail

# Source all include files using wildcard
for script in "${BASH_SOURCE[0]%/*}/../common.d"/*.sh; do
	[[ -f ${script} ]] && source "${script}"
done

# Load configuration
load_config

# Main build function
build_confext()
{
	check_mksquashfs

	local confext_overlay="${CONFEXT_OVERLAY_DIR}"
	local confext_name="${SYSEXT_NAME}"

	log_info "Building confext image '${confext_name}'..."

	# Check overlay directory
	if [[ ! -d ${confext_overlay} ]]; then
		log_error "Config overlay directory '${confext_overlay}' does not exist."
		exit 1
	fi

	# Create extension-release directory
	mkdir -p "${confext_overlay}/etc/extension-release.d"
	local extension_release_file="${confext_overlay}/etc/extension-release.d/extension-release.${confext_name}"

	# Replace Kubernetes version template in config files
	if [[ -f "${confext_overlay}/etc/kubeadm/init.yaml" ]]; then
		local k8s_version="${KUBECTL_VERSION}"

		# Resolve version if needed
		if [[ ${k8s_version} == "latest" ]]; then
			k8s_version=$(curl -sL https://dl.k8s.io/release/stable.txt)
		fi

		log_info "Setting Kubernetes version to ${k8s_version} in kubeadm config..."
		sed -i "s/__KUBERNETES_VERSION__/${k8s_version}/" "${confext_overlay}/etc/kubeadm/init.yaml"
	fi

	# Create extension-release file for confext
	log_info "Creating confext extension-release file..."
	create_confext_extension_release "${extension_release_file}"

	# Build squashfs image
	local output_file="${OUTPUT_DIR}/${confext_name}.confext.raw"
	build_squashfs_image "${confext_overlay}" "${output_file}"

	# Show result
	show_build_result "${output_file}" "${confext_name}" "confext"

	# Clean up extension-release file (leave config files intact)
	rm -f "${extension_release_file}"
}

# Run
build_confext
