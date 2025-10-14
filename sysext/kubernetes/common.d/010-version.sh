#!/bin/bash

# Get latest release version from GitHub API
get_latest_github_release()
{
	local repo="$1"
	local branch_prefix="${2:-}"
	local api_url="https://api.github.com/repos/${repo}/releases"

	if [[ -n ${branch_prefix} ]]; then
		log_info "Fetching latest ${branch_prefix}.x release for ${repo}..." >&2
	else
		log_info "Fetching latest release for ${repo}..." >&2
		api_url="${api_url}/latest"
	fi

	local response
	response=$(curl -sL "${api_url}")

	if [[ $? -ne 0 ]]; then
		log_error "Failed to fetch release info from ${api_url}" >&2
		return 1
	fi

	local version
	if [[ -n ${branch_prefix} ]]; then
		version=$(echo "${response}" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' | grep "^${branch_prefix}\." | head -n1)
	else
		version=$(echo "${response}" | grep '"tag_name":' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
	fi

	if [[ -z ${version} ]]; then
		log_error "Failed to parse version from GitHub API response" >&2
		return 1
	fi

	echo "${version}"
}

# Resolve version: handles "latest", specific version, or empty
resolve_version()
{
	local requested_version="$1"
	local repo="${2:-}" # GitHub repo for "latest" resolution

	if [[ -z ${requested_version} ]]; then
		return 1 # Skip this component
	fi

	if [[ ${requested_version} == "latest" ]]; then
		if [[ -n ${repo} ]]; then
			get_latest_github_release "${repo}"
		else
			# For kubernetes components
			curl -sL https://dl.k8s.io/release/stable.txt
		fi
	else
		echo "${requested_version}"
	fi
}

# Save version information
save_version()
{
	local app_name="$1"
	local version="$2"
	local version_file="${VERSION_DIR}/${app_name}.version"

	echo "${version}" > "${version_file}"
	log_info "Saved version ${version} to ${version_file}"
}
