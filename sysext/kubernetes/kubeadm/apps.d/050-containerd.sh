#!/bin/bash

download_containerd()
{
	local version="${1:-${CONTAINERD_VERSION:-}}"

	version=$(resolve_version "${version}" "containerd/containerd") || return 0

	# Remove 'v' prefix if present
	local clean_version="${version#v}"

	local url="https://github.com/containerd/containerd/releases/download/${version}/containerd-${clean_version}-linux-${DOWNLOAD_ARCH}.tar.gz"

	log_info "Downloading containerd ${version}..."

	if curl -L "${url}" | tar -xz -C "${BIN_DIR}" --strip-components=1 --wildcards "bin/*" 2> /dev/null; then
		chmod 0755 "${BIN_DIR}"/containerd* "${BIN_DIR}"/ctr "${BIN_DIR}"/containerd-shim* 2> /dev/null || true
		save_version "containerd" "${version}"
		log_info "Successfully downloaded containerd ${version}"
		echo
	else
		log_error "Failed to download and extract containerd"
		return 1
	fi
}
