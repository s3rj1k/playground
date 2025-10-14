#!/bin/bash

download_containerd()
{
	local version="${1:-${CONTAINERD_VERSION:-}}"

	if [[ ${version} == latest:* ]]; then
		local branch_prefix="${version#latest:}"
		version=$(get_latest_github_release "containerd/containerd" "${branch_prefix}") || return 0
	else
		version=$(resolve_version "${version}" "containerd/containerd") || return 0
	fi

	# Remove 'v' prefix if present
	local clean_version="${version#v}"

	local url="https://github.com/containerd/containerd/releases/download/${version}/containerd-${clean_version}-linux-${DOWNLOAD_ARCH}.tar.gz"
	local dest_dir="${CONTAINERD_DEST:-${BIN_DIR}}"

	log_info "Downloading containerd ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "${dest_dir}"

	if curl -L "${url}" | tar -xz -C "${dest_dir}" --strip-components=1 --wildcards "bin/*" 2> /dev/null; then
		chmod 0755 "${dest_dir}"/containerd* "${dest_dir}"/ctr "${dest_dir}"/containerd-shim* 2> /dev/null || true
		log_info "Downloaded to ${dest_dir}"
		save_version "containerd" "${version}"
		log_info "Successfully downloaded containerd ${version}"
		echo
	else
		log_error "Failed to download and extract containerd"
		return 1
	fi
}
