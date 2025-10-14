#!/bin/bash

download_kubeadm()
{
	local version="${1:-${KUBEADM_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kubeadm"
	local dest="${KUBERNETES_BIN_DIR}/kubeadm"

	log_info "Downloading kubeadm ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kubeadm" "${version}"
		log_info "Successfully downloaded kubeadm ${version}"
		echo
	else
		return 1
	fi
}
