#!/bin/bash

# Download a file from URL
download_file()
{
	local url="$1"
	local dest="$2"
	local mode="${3:-0755}"

	log_info "Downloading from ${url}..."

	if ! curl -L -o "${dest}" "${url}"; then
		log_error "Failed to download ${url}"
		return 1
	fi

	chmod "${mode}" "${dest}"
	log_info "Downloaded to ${dest}"
}
