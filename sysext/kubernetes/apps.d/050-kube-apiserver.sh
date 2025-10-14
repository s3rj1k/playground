#!/bin/bash

download_kube_apiserver()
{
	local version="${1:-${KUBE_APISERVER_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kube-apiserver"
	local dest="${KUBE_APISERVER_DEST:-${KUBERNETES_BIN_DIR}/kube-apiserver}"

	log_info "Downloading kube-apiserver ${version}..."

	mkdir -p "$(dirname "${dest}")"

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kube-apiserver" "${version}"
		log_info "Successfully downloaded kube-apiserver ${version}"
		echo
	else
		return 1
	fi
}
