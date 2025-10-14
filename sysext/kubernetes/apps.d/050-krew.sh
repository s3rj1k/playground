#!/bin/bash

download_krew()
{
	local version="${1:-${KREW_VERSION:-}}"

	version=$(resolve_version "${version}" "kubernetes-sigs/krew") || return 0

	local url="https://github.com/kubernetes-sigs/krew/releases/download/${version}/krew-linux_${DOWNLOAD_ARCH}.tar.gz"

	log_info "Downloading krew ${version}..."

	if curl -L "${url}" | tar -xzO "./krew-linux_${DOWNLOAD_ARCH}" > "${KUBERNETES_BIN_DIR}/krew" 2> /dev/null; then
		chmod 0755 "${KUBERNETES_BIN_DIR}/krew"
		save_version "krew" "${version}"
		log_info "Successfully downloaded krew ${version}"
		echo
	else
		log_error "Failed to download and extract krew"
		return 1
	fi
}
