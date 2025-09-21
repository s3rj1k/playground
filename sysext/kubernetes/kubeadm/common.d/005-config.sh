#!/bin/bash

# Load configuration from environment file
load_config()
{
	CONFIG_FILE="${CONFIG_FILE:-config.env}"
	if [[ -f ${CONFIG_FILE} ]]; then
		source "${CONFIG_FILE}"
	else
		log_error "Configuration file '${CONFIG_FILE}' not found"
		exit 1
	fi
}
