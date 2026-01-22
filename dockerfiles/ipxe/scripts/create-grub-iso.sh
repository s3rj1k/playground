#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2025 s3rj1k

set -euo pipefail

# Configuration
ISO_DIR=""
OUTPUT_ISO=""
IPXE_AMD64=""
IPXE_ARM64=""

log_info()
{
	echo "[INFO] $*"
}

log_error()
{
	echo "[ERROR] $*"
}

check_requirements()
{
	local missing=()

	# Check for grub-mkrescue or grub2-mkrescue
	if command -v grub-mkrescue &> /dev/null; then
		GRUB_MKRESCUE="grub-mkrescue"
	elif command -v grub2-mkrescue &> /dev/null; then
		GRUB_MKRESCUE="grub2-mkrescue"
	else
		missing+=("grub-mkrescue")
	fi

	if ! command -v xorriso &> /dev/null; then
		missing+=("xorriso")
	fi

	if [[ ${#missing[@]} -gt 0 ]]; then
		log_error "Missing required commands: ${missing[*]}"
		log_error "Debian/Ubuntu: sudo apt-get install grub-efi-amd64-bin grub-efi-arm64-bin xorriso"
		log_error "RHEL/CentOS: sudo dnf install grub2-tools-extra grub2-efi-x64-modules grub2-efi-aa64-modules xorriso"
		exit 1
	fi
}

cleanup()
{
	if [[ -n ${ISO_DIR:-} ]] && [[ -d $ISO_DIR ]]; then
		log_info "Cleaning up temporary directory..."
		rm -rf "$ISO_DIR"
	fi
}

trap cleanup EXIT

usage()
{
	cat << EOF
Usage: $0 [OPTIONS] --output <output.iso>

Create bootable GRUB EFI ISO with iPXE chainloading

Options:
    --ipxe-amd64 <path>         Path to AMD64 iPXE EFI file
    --ipxe-arm64 <path>         Path to ARM64 iPXE EFI file
    --output <path>             Output ISO file path
    --help                      Show this help message

Examples:
    # AMD64 ISO
    $0 --ipxe-amd64 ipxe.efi --output ipxe-grub-efi-amd64.iso

    # ARM64 ISO
    $0 --ipxe-arm64 ipxe.efi --output ipxe-grub-efi-arm64.iso
EOF
	exit 0
}

validate_inputs()
{
	if [[ -z $OUTPUT_ISO ]]; then
		log_error "Missing required argument: --output"
		exit 1
	fi

	if [[ -z $IPXE_AMD64 ]] && [[ -z $IPXE_ARM64 ]]; then
		log_error "At least one iPXE EFI file must be provided"
		exit 1
	fi

	# Check if files exist
	for file in "$IPXE_AMD64" "$IPXE_ARM64"; do
		if [[ -n $file ]] && [[ ! -f $file ]]; then
			log_error "File not found: $file"
			exit 1
		fi
	done

	if [[ -f $OUTPUT_ISO ]]; then
		log_error "Output file already exists: $OUTPUT_ISO"
		exit 1
	fi
}

create_grub_config()
{
	local grub_cfg="$1"

	cat > "$grub_cfg" << 'EOF'
set timeout=-1
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

insmod part_gpt
insmod fat
insmod chain
EOF

	if [[ -n $IPXE_AMD64 ]]; then
		cat >> "$grub_cfg" << 'EOF'

menuentry "iPXE" {
	search --no-floppy --file --set=root /ipxe/ipxe.efi
	chainloader ($root)/ipxe/ipxe.efi
	boot
}
EOF
	elif [[ -n $IPXE_ARM64 ]]; then
		cat >> "$grub_cfg" << 'EOF'

menuentry "iPXE" {
	search --no-floppy --file --set=root /ipxe/ipxe.efi
	chainloader ($root)/ipxe/ipxe.efi
	boot
}
EOF
	fi

	cat >> "$grub_cfg" << 'EOF'

menuentry "Reboot" {
	reboot
}

menuentry "Shutdown" {
	halt
}
EOF

	log_info "Created GRUB configuration"
}

create_iso()
{
	check_requirements
	validate_inputs

	# Create temporary directory
	ISO_DIR=$(mktemp -d -t grub-iso.XXXXXX)
	log_info "Using temporary directory: $ISO_DIR"

	# Create directory structure
	mkdir -p "$ISO_DIR/boot/grub"
	mkdir -p "$ISO_DIR/EFI/BOOT"
	mkdir -p "$ISO_DIR/ipxe"

	# Create GRUB configuration
	create_grub_config "$ISO_DIR/boot/grub/grub.cfg"
	cp "$ISO_DIR/boot/grub/grub.cfg" "$ISO_DIR/EFI/BOOT/grub.cfg"

	# Copy iPXE binary
	if [[ -n $IPXE_AMD64 ]]; then
		log_info "Copying AMD64 iPXE: $IPXE_AMD64"
		cp "$IPXE_AMD64" "$ISO_DIR/ipxe/ipxe.efi"
	elif [[ -n $IPXE_ARM64 ]]; then
		log_info "Copying ARM64 iPXE: $IPXE_ARM64"
		cp "$IPXE_ARM64" "$ISO_DIR/ipxe/ipxe.efi"
	fi

	# Create bootable ISO with grub-mkrescue
	log_info "Creating bootable ISO: $OUTPUT_ISO"

	# Include necessary modules for chainloading
	"$GRUB_MKRESCUE" -o "$OUTPUT_ISO" \
		--modules="part_gpt part_msdos fat iso9660 chain search normal configfile" \
		--compress=xz \
		"$ISO_DIR" 2>&1 | grep -v "xorriso : UPDATE" || true

	log_info "Successfully created bootable ISO: $OUTPUT_ISO"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
	case $1 in
		--ipxe-amd64)
			IPXE_AMD64="$2"
			shift 2
			;;
		--ipxe-arm64)
			IPXE_ARM64="$2"
			shift 2
			;;
		--output)
			OUTPUT_ISO="$2"
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

create_iso
