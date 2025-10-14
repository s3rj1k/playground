#!/bin/bash

download_runc()
{
	local version="${1:-${RUNC_VERSION:-}}"

	version=$(resolve_version "${version}" "opencontainers/runc") || return 0

	local url="https://github.com/opencontainers/runc/releases/download/${version}/runc.${DOWNLOAD_ARCH}"
	local dest="${RUNC_DEST:-${BIN_DIR}/runc}"

	log_info "Downloading runc ${version}..."

	mkdir -p "$(dirname "${dest}")"

	if download_file "${url}" "${dest}" "0755"; then
		save_version "runc" "${version}"
		log_info "Successfully downloaded runc ${version}"
		echo
	else
		return 1
	fi
}
