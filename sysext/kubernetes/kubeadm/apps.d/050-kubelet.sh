#!/bin/bash

download_kubelet()
{
	local version="${1:-${KUBELET_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kubelet"
	local dest="${BIN_DIR}/kubelet"

	log_info "Downloading kubelet ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kubelet" "${version}"
		log_info "Successfully downloaded kubelet ${version}"
		echo
	else
		return 1
	fi
}
