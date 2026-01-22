#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 s3rj1k

set -euo pipefail

# Configuration
IMAGE_SIZE_KB=""

log_info()
{
	echo "[INFO] $*"
}

log_warn()
{
	echo "[WARN] $*"
}

log_error()
{
	echo "[ERROR] $*"
}

check_requirements()
{
	local missing=()

	for cmd in mformat mcopy mmd xorriso truncate; do
		if ! command -v "$cmd" &> /dev/null; then
			missing+=("$cmd")
		fi
	done

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing required commands: ${missing[*]}"
		exit 1
	fi
}

usage()
{
	cat << EOF
Usage: $0 [OPTIONS] --output <output-base>

Create bootable iPXE EFI USB and ISO images

Options:
    --efi-amd64 <path>      Path to AMD64 iPXE EFI file
    --efi-arm64 <path>      Path to ARM64 iPXE EFI file
    --output <path>         Output base name (creates .img and .iso files)
    --size <kb>             Image size in KB (default: 1440)
                            Common sizes: 1440 (1.44MB), 2880 (2.88MB)
    --help                  Show this help message

Examples:
    # Single architecture AMD64
    $0 --efi-amd64 snponly.efi --output ipxe-efi-amd64

    # Single architecture ARM64
    $0 --efi-arm64 snponly.efi --output ipxe-efi-arm64

    # Dual architecture with custom size
    $0 --efi-amd64 snponly-x64.efi --efi-arm64 snponly-aa64.efi --size 2880 --output ipxe-efi-dual
EOF
	exit 0
}

validate_efi_files()
{
	local efi_amd64="$1"
	local efi_arm64="$2"

	if [[ -z $efi_amd64 ]] && [[ -z $efi_arm64 ]]; then
		log_error "At least one EFI file must be provided"
		exit 1
	fi

	if [[ -n $efi_amd64 ]] && [[ ! -f $efi_amd64 ]]; then
		log_error "AMD64 EFI file not found: $efi_amd64"
		exit 1
	fi

	if [[ -n $efi_arm64 ]] && [[ ! -f $efi_arm64 ]]; then
		log_error "ARM64 EFI file not found: $efi_arm64"
		exit 1
	fi

	if [[ -n $efi_amd64 ]] && [[ -n $efi_arm64 ]]; then
		log_info "Creating dual-architecture EFI images"
		log_info "AMD64 EFI: $efi_amd64"
		log_info "ARM64 EFI: $efi_arm64"
	elif [[ -n $efi_amd64 ]]; then
		log_info "Creating single-architecture EFI images (AMD64)"
		log_info "AMD64 EFI: $efi_amd64"
	else
		log_info "Creating single-architecture EFI images (ARM64)"
		log_info "ARM64 EFI: $efi_arm64"
	fi
}

set_image_size()
{
	local size="$1"

	if [[ -z $size ]]; then
		IMAGE_SIZE_KB=1440
	else
		IMAGE_SIZE_KB="$size"
	fi
}

copy_efi_files_to_image()
{
	local image_file="$1"
	local efi_amd64="$2"
	local efi_arm64="$3"

	log_info "Creating EFI directory structure..."
	mmd -i "$image_file" ::/EFI
	mmd -i "$image_file" ::/EFI/BOOT

	if [[ -n $efi_amd64 ]]; then
		log_info "Copying AMD64 EFI bootloader as BOOTX64.EFI..."
		mcopy -i "$image_file" "$efi_amd64" ::/EFI/BOOT/BOOTX64.EFI
	fi

	if [[ -n $efi_arm64 ]]; then
		log_info "Copying ARM64 EFI bootloader as BOOTAA64.EFI..."
		mcopy -i "$image_file" "$efi_arm64" ::/EFI/BOOT/BOOTAA64.EFI
	fi
}

create_efi_image()
{
	local output_image="$1"
	local efi_amd64="$2"
	local efi_arm64="$3"

	log_info "Creating USB image..."
	log_info "Output: $output_image"
	log_info "Size: ${IMAGE_SIZE_KB}KB"

	log_info "Creating unpartitioned FAT image..."
	truncate -s "${IMAGE_SIZE_KB}K" "$output_image"

	local mformat_args
	if [[ $IMAGE_SIZE_KB -eq 1440 ]]; then
		mformat_args="-f 1440"
	else
		# Calculate geometry for larger images (like iPXE does)
		local cylinders=$(((IMAGE_SIZE_KB + 503) / 504))
		mformat_args="-s 63 -h 16 -t ${cylinders}"
	fi

	log_info "Formatting as FAT filesystem..."
	# Word splitting intentional for multiple flags
	# shellcheck disable=SC2086
	mformat -v "iPXE" -i "$output_image" ${mformat_args} ::

	log_info "Copying EFI files to image..."
	copy_efi_files_to_image "$output_image" "$efi_amd64" "$efi_arm64"

	log_info "Successfully created bootable EFI USB image: $output_image"
}

create_iso_image()
{
	local output_image="$1"
	local usb_image="$2"

	log_info "Creating ISO image with xorriso from USB image..."
	log_info "Output: $output_image"

	xorriso -as mkisofs \
		-o "$output_image" \
		-e "$(basename "$usb_image")" \
		-no-emul-boot \
		-R \
		-J \
		-V "iPXE" \
		"$usb_image"

	log_info "Successfully created bootable EFI ISO image: $output_image"
}

create_images()
{
	local output_base="$1"
	local efi_amd64="$2"
	local efi_arm64="$3"
	local size="$4"

	if [[ -z $output_base ]]; then
		log_error "Missing required argument: --output"
		exit 1
	fi

	local usb_image="${output_base}.img"
	if [[ -f $usb_image ]]; then
		log_error "Output file already exists: $usb_image"
		exit 1
	fi

	local iso_image="${output_base}.iso"
	if [[ -f $iso_image ]]; then
		log_error "Output file already exists: $iso_image"
		exit 1
	fi

	check_requirements

	validate_efi_files "$efi_amd64" "$efi_arm64"
	set_image_size "$size"

	create_efi_image "$usb_image" "$efi_amd64" "$efi_arm64"
	create_iso_image "$iso_image" "$usb_image"

	log_info "USB: $usb_image"
	log_info "ISO: $iso_image"
}

# Parse command line arguments
EFI_AMD64=""
EFI_ARM64=""
OUTPUT_BASE=""
IMAGE_SIZE=""

while [[ $# -gt 0 ]]; do
	case $1 in
		--efi-amd64)
			EFI_AMD64="$2"
			shift 2
			;;
		--efi-arm64)
			EFI_ARM64="$2"
			shift 2
			;;
		--output)
			OUTPUT_BASE="$2"
			shift 2
			;;
		--size)
			IMAGE_SIZE="$2"
			shift 2
			;;
		--help | -h)
			usage
			;;
		*)
			log_error "Unknown option: $1"
			usage
			;;
	esac
done

create_images "$OUTPUT_BASE" "$EFI_AMD64" "$EFI_ARM64" "$IMAGE_SIZE"
