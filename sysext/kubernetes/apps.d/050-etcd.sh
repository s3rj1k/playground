#!/bin/bash

download_etcd()
{
	local version="${1:-${ETCD_VERSION:-}}"

	version=$(resolve_version "${version}" "etcd-io/etcd") || return 0

	local url="https://github.com/etcd-io/etcd/releases/download/${version}/etcd-${version}-linux-${DOWNLOAD_ARCH}.tar.gz"
	local dest_dir="${ETCD_DEST:-${KUBERNETES_BIN_DIR}}"

	log_info "Downloading etcd ${version}..."
	log_info "Downloading from ${url}..."

	mkdir -p "${dest_dir}"

	if curl -L "${url}" | tar -xz -C "${dest_dir}" --strip-components=1 --wildcards "*/etcd" "*/etcdctl" "*/etcdutl" 2> /dev/null; then
		chmod 0755 "${dest_dir}/etcd" "${dest_dir}/etcdctl" "${dest_dir}/etcdutl" 2> /dev/null || true
		log_info "Downloaded to ${dest_dir}"
		save_version "etcd" "${version}"
		log_info "Successfully downloaded etcd ${version}"
		echo
	else
		log_error "Failed to download and extract etcd"
		return 1
	fi
}
