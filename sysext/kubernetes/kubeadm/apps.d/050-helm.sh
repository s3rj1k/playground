#!/bin/bash

download_helm()
{
	local version="${1:-${HELM_VERSION:-}}"

	version=$(resolve_version "${version}" "helm/helm") || return 0

	local url="https://get.helm.sh/helm-${version}-linux-${DOWNLOAD_ARCH}.tar.gz"

	log_info "Downloading helm ${version}..."

	if curl -L "${url}" | tar -xzO "linux-${DOWNLOAD_ARCH}/helm" > "${KUBERNETES_BIN_DIR}/helm"; then
		chmod 0755 "${KUBERNETES_BIN_DIR}/helm"
		save_version "helm" "${version}"
		log_info "Successfully downloaded helm ${version}"
		echo
	else
		log_error "Failed to download and extract helm"
		return 1
	fi
}
