#!/usr/bin/env bash
# =========================================================================
# Wrapper: reads resource settings from config file and submits
# run_download_and_process.sh unmodified.
# =========================================================================

set -euo pipefail

# Get config file from first argument, default to config/default.sh
CONFIG_FILE="${1:-config/default.sh}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

# Create log directory
mkdir -p "${LOG_DIR}"

# Build account flag only if PROJECT_CODE is non-empty
ACCOUNT_FLAG=()
if [[ -n "${PROJECT_CODE}" ]]; then
    ACCOUNT_FLAG=(--account="${PROJECT_CODE}")
fi

# Submit or run locally
if [[ "${RUN_MODE}" == "local" ]]; then
    echo "Running run_download_and_process.sh locally with config: ${CONFIG_FILE}"
    CONFIG_FILE="${CONFIG_FILE}" bash run_download_and_process.sh
else
    echo "Submitting run_download_and_process.sh to Slurm with config: ${CONFIG_FILE}"
    sbatch \
        -n "${PREP_NTASKS}" \
        -N "${PREP_NNODES}" \
        -t "${PREP_TIME}" \
        -o "${LOG_DIR}/log.prep_density_data_%j.out" \
        "${ACCOUNT_FLAG[@]}" \
        --export=CONFIG_FILE="${CONFIG_FILE}" \
        run_download_and_process.sh
fi