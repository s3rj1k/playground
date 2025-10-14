#!/bin/bash

download_kube_controller_manager()
{
	local version="${1:-${KUBE_CONTROLLER_MANAGER_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kube-controller-manager"
	local dest="${KUBE_CONTROLLER_MANAGER_DEST:-${KUBERNETES_BIN_DIR}/kube-controller-manager}"

	log_info "Downloading kube-controller-manager ${version}..."

	mkdir -p "$(dirname "${dest}")"

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kube-controller-manager" "${version}"
		log_info "Successfully downloaded kube-controller-manager ${version}"
		echo
	else
		return 1
	fi
}
