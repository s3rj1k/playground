#!/bin/bash

download_cni_plugins()
{
	local version="${1:-${CNI_PLUGINS_VERSION:-}}"

	version=$(resolve_version "${version}" "containernetworking/plugins") || return 0

	# Remove 'v' prefix if present
	local clean_version="${version#v}"

	local url="https://github.com/containernetworking/plugins/releases/download/${version}/cni-plugins-linux-${DOWNLOAD_ARCH}-${version}.tgz"
	local cni_dir="${CNI_PLUGINS_DEST:-${SYSEXT_OVERLAY_DIR}/opt/cni/bin}"

	log_info "Downloading CNI plugins ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "${cni_dir}"

	if curl -L "${url}" | tar -xz -C "${cni_dir}" 2> /dev/null; then
		chmod 0755 "${cni_dir}"/* 2> /dev/null || true
		log_info "Downloaded to ${cni_dir}"
		save_version "cni-plugins" "${version}"
		log_info "Successfully downloaded CNI plugins ${version}"
		echo
	else
		log_error "Failed to download and extract CNI plugins"
		return 1
	fi
}
