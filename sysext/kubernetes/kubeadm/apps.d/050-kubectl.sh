#!/bin/bash

download_kubectl()
{
	local version="${1:-${KUBECTL_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kubectl"
	local dest="${KUBERNETES_BIN_DIR}/kubectl"

	log_info "Downloading kubectl ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kubectl" "${version}"
		log_info "Successfully downloaded kubectl ${version}"
		echo
	else
		return 1
	fi
}
