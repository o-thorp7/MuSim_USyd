#!/usr/bin/env bash
#
# Combines muflux outputs from all zenith angles into one flux curve.
#
# Usage:
#   ./combine_muflux_files.sh config/conda_test.sh
#

set -euo pipefail

# Get config file from first argument, default to config/default.sh
CONFIG_FILE="${1:-config/default.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

# Set directories
INPUT_DIR="${SPLINE_DIR}"
OUTPUT_DIR="${MUFLUX_DIR}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Match files like: avg_spline_2026-06-09_03UTC.npy
shopt -s nullglob
FILES=("${INPUT_DIR}"/avg_spline_*.npy)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No matching .npy files found in ${INPUT_DIR}" >&2
    exit 1
fi

for f in "${FILES[@]}"; do
    fname=$(basename "${f}")

    # Extract the timestamp (e.g. 2026-06-09_03UTC) from the filename
    if [[ "${fname}" =~ avg_spline_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}UTC)\.npy$ ]]; then
        timestamp="${BASH_REMATCH[1]}"
    else
        echo "Skipping unrecognized filename format: ${fname}" >&2
        continue
    fi

    echo "combining files for ${timestamp}"
    python3 combine_muflux_files.py ${timestamp} "${OUTPUT_DIR}"

done