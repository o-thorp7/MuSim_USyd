#!/usr/bin/env bash
#
# Submits one Slurm job per density_era5_hires_*.pkl file, running
# make_slice_spline.py and writing a uniquely-named output spline.
#
# Usage:
#   ./submit_spline_jobs.sh config/conda_test.sh
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
INPUT_DIR="${DENSITY_DIR}/era5_hires"
OUTPUT_DIR="${SPLINE_DIR}"

# Create output and log directories
mkdir -p "${OUTPUT_DIR}" "${LOG_DIR}"

# Match files like: density_era5_hires_2026-06-09_03UTC.pkl
shopt -s nullglob
FILES=("${INPUT_DIR}"/density_era5_hires_*.pkl)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No matching .pkl files found in ${INPUT_DIR}" >&2
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
    if [[ "${fname}" =~ density_era5_hires_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}UTC)\.pkl$ ]]; then
        timestamp="${BASH_REMATCH[1]}"
    else
        echo "Skipping unrecognized filename format: ${fname}" >&2
        continue
    fi

    outfile="${OUTPUT_DIR}/avg_spline_${timestamp}.npy"
    jobname="spline_${timestamp}"

    echo -e "Submitting job for ${fname} ->\n${outfile}\n"

    if [[ "${RUN_MODE}" == "local" ]]; then
        echo -e "Running locally: submit_slice_spline.sh \ninfile: ${f}\nlon, lat: ${LON} ${LAT}\noutfile: ${outfile}\n\n"
        CONFIG_FILE="${CONFIG_FILE}" bash submit_slice_spline.sh ${f} ${LON} ${LAT} ${outfile} >& "${LOG_DIR}/${jobname}.log" &
        PIDS+=("$!")
    else
        jid=$(sbatch --parsable ${ACCOUNT_FLAG[@]+"${ACCOUNT_FLAG[@]}"} --job-name="${jobname}" \
            --mem="${SPLINE_MEM}" --time="${SPLINE_TIME}" --output="${LOG_DIR}/${jobname}_%j.out" \
            --error="${LOG_DIR}/${jobname}_%j.err" --export=CONFIG_FILE="${CONFIG_FILE}" \
            --cpus-per-task="${SPLINE_NCPUS}" \
            submit_slice_spline.sh ${f} ${LON} ${LAT} ${outfile}) \
        JOBIDS+=("${jid}")
    fi
done

if [[ "${RUN_MODE}" == "local" ]]; then
    printf '%s\n' "${PIDS[@]}" > "${LOG_DIR}/spline.pids"
    echo -e "Started ${#PIDS[@]} spline job(s) in background. PIDs saved to ${LOG_DIR}/spline.pids\n"
    echo -e "To stop all: kill \$(cat ${LOG_DIR}/spline.pids)\n"
    echo "To check if still running: ps -fp \$(cat ${LOG_DIR}/spline.pids)"
else
    printf '%s\n' "${JOBIDS[@]}" > "${LOG_DIR}/spline.jobids"
    echo -e "Submitted ${#JOBIDS[@]} Slurm job(s). IDs saved to ${LOG_DIR}/spline.jobids\n"
    echo -e "To stop all: scancel \$(cat ${LOG_DIR}/spline.jobids)\n"
    echo "To check progress: squeue -u \$USER"
fi