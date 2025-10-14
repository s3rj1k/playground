#!/bin/bash

download_cilium()
{
	local version="${1:-${CILIUM_VERSION:-}}"

	version=$(resolve_version "${version}" "cilium/cilium-cli") || return 0

	local url="https://github.com/cilium/cilium-cli/releases/download/${version}/cilium-linux-${DOWNLOAD_ARCH}.tar.gz"
	local dest="${CILIUM_DEST:-${KUBERNETES_BIN_DIR}/cilium}"

	log_info "Downloading cilium CLI ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "$(dirname "${dest}")"

	if curl -L "${url}" | tar -xzO "cilium" > "${dest}"; then
		chmod 0755 "${dest}"
		log_info "Downloaded to ${dest}"
		save_version "cilium" "${version}"
		log_info "Successfully downloaded cilium CLI ${version}"
		echo
	else
		log_error "Failed to download and extract cilium CLI"
		return 1
	fi
}
