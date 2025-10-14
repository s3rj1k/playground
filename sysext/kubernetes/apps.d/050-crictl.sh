#!/bin/bash

download_crictl()
{
	local version="${1:-${CRICTL_VERSION:-}}"

	version=$(resolve_version "${version}" "kubernetes-sigs/cri-tools") || return 0

	local url="https://github.com/kubernetes-sigs/cri-tools/releases/download/${version}/crictl-${version}-linux-${DOWNLOAD_ARCH}.tar.gz"
	local dest="${CRICTL_DEST:-${BIN_DIR}/crictl}"

	log_info "Downloading crictl ${version}..."

	mkdir -p "$(dirname "${dest}")"

	local temp_dir
	temp_dir=$(mktemp -d)
	local temp_file="${temp_dir}/crictl.tar.gz"

	if download_file "${url}" "${temp_file}"; then
		tar -xzf "${temp_file}" -C "${temp_dir}" crictl
		mv "${temp_dir}/crictl" "${dest}"
		chmod 0755 "${dest}"
		rm -rf "${temp_dir}"

		save_version "crictl" "${version}"
		log_info "Successfully downloaded crictl ${version}"
		echo
	else
		rm -rf "${temp_dir}"
		return 1
	fi
}
