#!/usr/bin/env bash
#
# Submits one Slurm job per avg_spline_*.npy file, running
# muflux_calc.py for each zenith angle.
#
# Usage:
#   ./submit_muflux_jobs.sh config/conda_test.sh
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

PIDS=()
JOBIDS=()

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

        echo -e "Submitting job for ${fname} ->\n${outfile}\n"

        if [[ "${RUN_MODE}" == "local" ]]; then
            echo -e "Running locally: submit_muflux_calc.sh \ninfile: ${f}\nlon, lat: ${LON} ${LAT}\noutfile: ${outfile}\n\n"
            CONFIG_FILE="${CONFIG_FILE}" bash submit_muflux_calc.sh ${f} ${th} ${outfile} >& "${LOG_DIR}/${jobname}.log" &
            PIDS+=("$!")
        else
            jid=$(sbatch --parsable ${ACCOUNT_FLAG[@]+"${ACCOUNT_FLAG[@]}"} --job-name="${jobname}" \
                --mem="${MUFLUX_MEM}" --time="${MUFLUX_TIME}" --output="${LOG_DIR}/${jobname}_%j.out" \
                --error="${LOG_DIR}/${jobname}_%j.err" --export=CONFIG_FILE="${CONFIG_FILE}" \
                --cpus-per-task="${MUFLUX_NCPUS}" \
                submit_muflux_calc.sh ${f} ${th} ${outfile})
            JOBIDS+=("${jid}")
        fi
    done
done

if [[ "${RUN_MODE}" == "local" ]]; then
    printf '%s\n' "${PIDS[@]}" > "${LOG_DIR}/muflux.pids"
    echo -e "Started ${#PIDS[@]} muflux job(s) in background. PIDs saved to ${LOG_DIR}/muflux.pids\n"
    echo -e "To stop all: kill \$(cat ${LOG_DIR}/muflux.pids)\n"
    echo "To check if still running: ps -fp \$(cat ${LOG_DIR}/muflux.pids)"
else
    printf '%s\n' "${JOBIDS[@]}" > "${LOG_DIR}/muflux.jobids"
    echo -e "Submitted ${#JOBIDS[@]} Slurm job(s). IDs saved to ${LOG_DIR}/muflux.jobids\n"
    echo -e "To stop all: scancel \$(cat ${LOG_DIR}/muflux.jobids)\n"
    echo "To check progress: squeue -u \$USER"
fi