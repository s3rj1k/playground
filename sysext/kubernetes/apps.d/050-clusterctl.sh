#!/bin/bash

download_clusterctl()
{
	local version="${1:-${CLUSTERCTL_VERSION:-}}"

	version=$(resolve_version "${version}" "kubernetes-sigs/cluster-api") || return 0

	local url="https://github.com/kubernetes-sigs/cluster-api/releases/download/${version}/clusterctl-linux-${DOWNLOAD_ARCH}"
	local dest="${CLUSTERCTL_DEST:-${KUBERNETES_BIN_DIR}/clusterctl}"

	log_info "Downloading clusterctl ${version}..."

	mkdir -p "$(dirname "${dest}")"

	if download_file "${url}" "${dest}" "0755"; then
		save_version "clusterctl" "${version}"
		log_info "Successfully downloaded clusterctl ${version}"
		echo
	else
		return 1
	fi
}
