#!/bin/bash
#
# Submits one Slurm job per avg_spline_*.npy file, running
# muflux_calc.py for each zenith angle.
#
# Usage:
#   ./submit_muflux_jobs.sh
#

set -euo pipefail

# Load configuration
. config.sh

# Set directories for this pipeline stage
INPUT_DIR="${SPLINE_DIR}"
OUTPUT_DIR="${MUFLUX_DIR}"

# Create output and log directories
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Match files like: avg_spline_2026-06-09_03UTC.npy
shopt -s nullglob
FILES=("${INPUT_DIR}"/avg_spline_*.npy)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No matching .npy files found in ${INPUT_DIR}" >&2
    exit 1
fi

# Build account flag only if PROJECT_CODE is non-empty
ACCOUNT_FLAG=()
if [[ -n "${PROJECT_CODE}" ]]; then
    ACCOUNT_FLAG=(--account="${PROJECT_CODE}")
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

    for th in $(seq ${THETA_MIN} ${THETA_STEP} ${THETA_MAX}); do
        outfile="${OUTPUT_DIR}/muflux_${timestamp}_${th}.npy"
        jobname="muflux_${timestamp}_${th}"

        echo "Submitting job for ${fname} theta=${th} -> ${outfile}"

        if [[ "${RUN_MODE}" == "local" ]]; then
            echo "Running locally: submit_muflux_calc.sh ${f} ${th} ${outfile}"
            bash submit_muflux_calc.sh ${f} ${th} ${outfile} >& "${LOG_DIR}/${jobname}.log" &
        else
            sbatch "${ACCOUNT_FLAG[@]}" --mem="${MUFLUX_MEM}" --time="${MUFLUX_TIME}" \
                --output="${LOG_DIR}/${jobname}_%j.out" --error="${LOG_DIR}/${jobname}_%j.err" \
                submit_muflux_calc.sh ${f} ${th} ${outfile}
        fi
    done
done