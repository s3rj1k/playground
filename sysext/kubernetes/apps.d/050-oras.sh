#!/bin/bash

download_oras()
{
	local version="${1:-${ORAS_VERSION:-}}"

	version=$(resolve_version "${version}" "oras-project/oras") || return 0

	# Remove 'v' prefix if present for the filename
	local clean_version="${version#v}"

	local url="https://github.com/oras-project/oras/releases/download/${version}/oras_${clean_version}_linux_${DOWNLOAD_ARCH}.tar.gz"
	local dest="${ORAS_DEST:-${OPT_BIN_DIR}/oras}"

	log_info "Downloading oras ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "$(dirname "${dest}")"

	if curl -L "${url}" | tar -xzO "oras" > "${dest}"; then
		chmod 0755 "${dest}"
		log_info "Downloaded to ${dest}"
		save_version "oras" "${version}"
		log_info "Successfully downloaded oras ${version}"
		echo
	else
		log_error "Failed to download and extract oras"
		return 1
	fi
}
