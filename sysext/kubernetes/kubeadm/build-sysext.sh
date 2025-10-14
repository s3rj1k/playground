#!/bin/bash

# https://uapi-group.org/specifications/specs/extension_image/

set -euo pipefail

# Source all include files using wildcard
for script in "${BASH_SOURCE[0]%/*}/../common.d"/*.sh; do
	[[ -f ${script} ]] && source "${script}"
done

# Load configuration
load_config

# Main build function
build_sysext()
{
	check_mksquashfs

	# Check overlay directory
	if [[ ! -d ${SYSEXT_OVERLAY_DIR} ]]; then
		log_error "Overlay directory '${SYSEXT_OVERLAY_DIR}' does not exist."
		exit 1
	fi

	log_info "Building sysext image '${SYSEXT_NAME}'..."

	# Create extension-release file directly in overlay
	local extension_release_dir="${SYSEXT_OVERLAY_DIR}/usr/lib/extension-release.d"
	mkdir -p "${extension_release_dir}"
	local extension_release_file="${extension_release_dir}/extension-release.${SYSEXT_NAME}"

	log_info "Creating extension-release file..."
	create_base_extension_release "${extension_release_file}"

	# Add binary version information
	if [[ -d ${SYSEXT_OVERLAY_DIR} ]]; then
		echo "" >> "${extension_release_file}"

		for version_file in "${SYSEXT_OVERLAY_DIR}"/*.version; do
			if [[ -f ${version_file} ]]; then
				local app_name=$(basename "${version_file}" .version)
				local version=$(cat "${version_file}")
				echo "# ${app_name^^}_VERSION=${version}" >> "${extension_release_file}"
			fi
		done
	fi

	# Build squashfs image
	local output_file="${OUTPUT_DIR}/${SYSEXT_NAME}.sysext.raw"
	build_squashfs_image "${SYSEXT_OVERLAY_DIR}" "${output_file}"

	# Show result
	show_build_result "${output_file}" "${SYSEXT_NAME}" "sysext"
}

# Run
build_sysext
