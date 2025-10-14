#!/bin/bash

download_envsubst()
{
	local version="${1:-${ENVSUBST_VERSION:-}}"

	version=$(resolve_version "${version}" "a8m/envsubst") || return 0

	local envsubst_arch
	case "${DOWNLOAD_ARCH}" in
		amd64) envsubst_arch="x86_64" ;;
		arm64) envsubst_arch="arm64" ;;
		*) envsubst_arch="${DOWNLOAD_ARCH}" ;;
	esac

	local url="https://github.com/a8m/envsubst/releases/download/${version}/envsubst-Linux-${envsubst_arch}"
	local dest="${OPT_BIN_DIR}/envsubst"

	log_info "Downloading envsubst ${version}..."

	if download_file "${url}" "${dest}" "0755"; then
		save_version "envsubst" "${version}"
		log_info "Successfully downloaded envsubst ${version}"
		echo
	else
		return 1
	fi
}
