#!/bin/bash

# Check if mksquashfs is available
check_mksquashfs()
{
	if ! command -v mksquashfs &> /dev/null; then
		log_error "mksquashfs not found."
		exit 1
	fi
}

# Build squashfs image
build_squashfs_image()
{
	local overlay_dir="$1"
	local output_file="$2"

	mkdir -p "$(dirname "${output_file}")"

	log_info "Building image with mksquashfs..."
	if ! mksquashfs "${overlay_dir}" "${output_file}" -all-root -noappend; then
		log_error "Failed to create image"
		return 1
	fi
}
