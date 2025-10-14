#!/bin/bash

download_yq()
{
	local version="${1:-${YQ_VERSION:-}}"

	version=$(resolve_version "${version}" "mikefarah/yq") || return 0

	local url="https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${DOWNLOAD_ARCH}"
	local dest="${OPT_BIN_DIR}/yq"

	log_info "Downloading yq ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "yq" "${version}"
		log_info "Successfully downloaded yq ${version}"
		echo
	else
		return 1
	fi
}
