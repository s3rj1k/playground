#!/bin/bash

# Create base extension-release content
create_base_extension_release()
{
	local release_file="$1"

	echo "ID=${ID}" > "${release_file}"
	[[ -n ${VERSION_ID} ]] && echo "VERSION_ID=${VERSION_ID}" >> "${release_file}"
	[[ -n ${ARCHITECTURE} ]] && echo "ARCHITECTURE=${ARCHITECTURE}" >> "${release_file}"
	[[ -n ${SYSEXT_LEVEL} ]] && echo "SYSEXT_LEVEL=${SYSEXT_LEVEL}" >> "${release_file}"
	echo "SYSEXT_SCOPE=${SYSEXT_SCOPE}" >> "${release_file}"
}

# Create confext extension-release content
create_confext_extension_release()
{
	local release_file="$1"

	echo "ID=${ID}" > "${release_file}"
	[[ -n ${VERSION_ID} ]] && echo "VERSION_ID=${VERSION_ID}" >> "${release_file}"
	[[ -n ${ARCHITECTURE} ]] && echo "ARCHITECTURE=${ARCHITECTURE}" >> "${release_file}"
	[[ -n ${SYSEXT_LEVEL} ]] && echo "CONFEXT_LEVEL=${SYSEXT_LEVEL}" >> "${release_file}"
	echo "SYSEXT_SCOPE=${SYSEXT_SCOPE}" >> "${release_file}"
}

# Display build result
show_build_result()
{
	local output_file="$1"
	local image_name="$2"
	local image_type="${3:-extension}"

	local size
	size=$(du -h "${output_file}" | cut -f1)

	echo
	echo "Successfully created ${image_type} image:"
	echo "  File: ${output_file}"
	echo "  Name: ${image_name}"
	echo "  OS ID: ${ID}"
	echo "  Size: ${size}"
}
