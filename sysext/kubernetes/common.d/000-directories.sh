#!/bin/bash

# Create necessary directories
ensure_directories()
{
	mkdir -p "${BIN_DIR}"
	mkdir -p "${OPT_BIN_DIR}"
	mkdir -p "${KUBERNETES_BIN_DIR}"
	mkdir -p "${VERSION_DIR}"
}
