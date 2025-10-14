#!/bin/bash

# Map ARCHITECTURE to download arch format
map_architecture()
{
	case "${ARCHITECTURE}" in
		x86-64 | x86_64 | amd64)
			DOWNLOAD_ARCH="amd64"
			;;
		aarch64 | arm64)
			DOWNLOAD_ARCH="arm64"
			;;
		armv7 | armv7l | arm)
			DOWNLOAD_ARCH="arm"
			;;
		*)
			log_error "Unsupported architecture: ${ARCHITECTURE}"
			exit 1
			;;
	esac
}
