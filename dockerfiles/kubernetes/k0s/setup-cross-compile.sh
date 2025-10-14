#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
	echo "Please run as root or with sudo"
	exit 1
fi

ARCH=$(uname -m)
echo "Setting up cross-platform compilation on $ARCH..."

apt-get update -qq
apt-get install -y -qq qemu-user-static binfmt-support

mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2> /dev/null || true

if [ "$ARCH" = "x86_64" ]; then
	echo ':qemu-aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-aarch64-static:F' > /proc/sys/fs/binfmt_misc/register 2> /dev/null || true
	TEST_PLATFORM="linux/arm64"
elif [ "$ARCH" = "aarch64" ]; then
	echo ':qemu-x86_64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x3e\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-x86_64-static:F' > /proc/sys/fs/binfmt_misc/register 2> /dev/null || true
	TEST_PLATFORM="linux/amd64"
else
	echo "Unsupported architecture: $ARCH"
	exit 1
fi

update-binfmts --enable 2> /dev/null || true

if docker run --rm --platform "$TEST_PLATFORM" alpine uname -m > /dev/null 2>&1; then
	echo "✓ Cross-platform compilation ready"
else
	echo "✗ Cross-platform test failed"
	exit 1
fi
