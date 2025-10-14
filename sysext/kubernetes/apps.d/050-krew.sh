#!/bin/bash

download_krew()
{
	local version="${1:-${KREW_VERSION:-}}"

	version=$(resolve_version "${version}" "kubernetes-sigs/krew") || return 0

	local url="https://github.com/kubernetes-sigs/krew/releases/download/${version}/krew-linux_${DOWNLOAD_ARCH}.tar.gz"
	local dest="${KREW_DEST:-${KUBERNETES_BIN_DIR}/krew}"

	log_info "Downloading krew ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "$(dirname "${dest}")"

	if curl -L "${url}" | tar -xzO "./krew-linux_${DOWNLOAD_ARCH}" > "${dest}" 2> /dev/null; then
		chmod 0755 "${dest}"
		log_info "Downloaded to ${dest}"
		save_version "krew" "${version}"
		log_info "Successfully downloaded krew ${version}"
		echo
	else
		log_error "Failed to download and extract krew"
		return 1
	fi
}
