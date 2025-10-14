#!/bin/bash

download_jq()
{
	local version="${1:-${JQ_VERSION:-}}"

	version=$(resolve_version "${version}" "jqlang/jq") || return 0

	local url="https://github.com/jqlang/jq/releases/download/${version}/jq-linux-${DOWNLOAD_ARCH}"
	local dest="${OPT_BIN_DIR}/jq"

	log_info "Downloading jq ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "jq" "${version}"
		log_info "Successfully downloaded jq ${version}"
		echo
	else
		return 1
	fi
}
