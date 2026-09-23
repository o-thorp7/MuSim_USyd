#!/bin/bash
# =========================================================================
# Wrapper: reads resource settings from config.sh and submits
# run_download_and_process.sh unmodified.
# =========================================================================

set -euo pipefail

# Load configuration
. config.sh

# Create log directory
mkdir -p "${LOG_DIR}"

# Build account flag only if PROJECT_CODE is non-empty
ACCOUNT_FLAG=()
if [[ -n "${PROJECT_CODE}" ]]; then
    ACCOUNT_FLAG=(--account="${PROJECT_CODE}")
fi

# Submit or run locally
if [[ "${RUN_MODE}" == "local" ]]; then
    echo "Running run_download_and_process.sh locally..."
    bash run_download_and_process.sh
else
    echo "Submitting run_download_and_process.sh to Slurm..."
    sbatch \
        -n "${PREP_NTASKS}" \
        -N "${PREP_NNODES}" \
        -t "${PREP_TIME}" \
        -o "${LOG_DIR}/log.prep_density_data_%j.out" \
        "${ACCOUNT_FLAG[@]}" \
        run_download_and_process.sh
fi