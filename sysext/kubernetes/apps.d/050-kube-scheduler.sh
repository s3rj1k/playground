#!/bin/bash

download_kube_scheduler()
{
	local version="${1:-${KUBE_SCHEDULER_VERSION:-}}"

	version=$(resolve_version "${version}") || return 0

	local url="https://dl.k8s.io/release/${version}/bin/linux/${DOWNLOAD_ARCH}/kube-scheduler"
	local dest="${KUBE_SCHEDULER_DEST:-${KUBERNETES_BIN_DIR}/kube-scheduler}"

	log_info "Downloading kube-scheduler ${version}..."

	mkdir -p "$(dirname "${dest}")"

	if download_file "${url}" "${dest}" "0755"; then
		save_version "kube-scheduler" "${version}"
		log_info "Successfully downloaded kube-scheduler ${version}"
		echo
	else
		return 1
	fi
}
