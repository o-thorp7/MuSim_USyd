#!/usr/bin/env bash

set -euo pipefail

# Get config file from first argument, default to config/default.sh
CONFIG_FILE="${1:-config/default.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

python3 extract_psfc_muflux.py "${LON}" "${LAT}" "${DENSITY_DIR}" "${MUFLUX_DIR}" "${BASE_DIR}"