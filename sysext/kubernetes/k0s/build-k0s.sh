#!/bin/bash

set -euo pipefail

# Source all include files using wildcard
for script in "${BASH_SOURCE[0]%/*}/../common.d"/*.sh; do
	[[ -f ${script} ]] && source "${script}"
done

# Load configuration
load_config

# K0s build configuration
K0S_DOCKERFILE_DIR="${BASH_SOURCE[0]%/*}/../../../dockerfiles/kubernetes/k0s"
K0S_VERSION="${K0S_VERSION:-release-1.34}"
K0S_REPO="${K0S_REPO:-https://github.com/k0sproject/k0s.git}"
K0S_IMAGE_TAG="k0s-build:${K0S_VERSION}"

# Detect platform - build for current architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]]; then
	PLATFORM="linux/arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
	PLATFORM="linux/amd64"
else
	PLATFORM="linux/$ARCH"
fi

log_info "Building k0s ${K0S_VERSION} for ${PLATFORM}..."

# Build k0s using Docker
docker buildx build \
	--platform "${PLATFORM}" \
	--build-arg K0S_VERSION="${K0S_VERSION}" \
	--build-arg K0S_REPO="${K0S_REPO}" \
	-f "${K0S_DOCKERFILE_DIR}/k0s-no-embedded-binaries.Dockerfile" \
	-t "${K0S_IMAGE_TAG}" \
	--load \
	"${K0S_DOCKERFILE_DIR}"

log_info "Extracting k0s binary..."

# Create container
container_id=$(docker create "${K0S_IMAGE_TAG}")

# Extract k0s binary and version file to sysext overlay
dest_dir="${SYSEXT_OVERLAY_DIR}/usr/bin"
mkdir -p "${dest_dir}"
docker cp "${container_id}:/usr/local/bin/k0s" "${dest_dir}/k0s"
docker cp "${container_id}:/usr/local/bin/k0s.version" "${SYSEXT_OVERLAY_DIR}/k0s.version"

# Remove container
docker rm "${container_id}" > /dev/null

k0s_version=$(cat "${SYSEXT_OVERLAY_DIR}/k0s.version")
log_info "k0s ${k0s_version} installed"
