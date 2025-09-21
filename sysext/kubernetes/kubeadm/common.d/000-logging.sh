#!/bin/bash

# Logging functions
log_info()
{
	echo "[INFO] $*"
}

log_warn()
{
	echo "[WARN] $*" >&2
}

log_error()
{
	echo "[ERROR] $*" >&2
}
