#!/usr/bin/env bash
# =========================================================================
# Wrapper: reads resource settings from config file and submits
# run_download_and_process.sh unmodified.
#
# This is the first stage of the pipeline, so it creates a new run directory
# results/<config>/<YYYY-MM-DD>[_N]/ that later stages pick up automatically.
#
# Usage:
#   ./submit_prep_density_data.sh [config] [--resume]
#
#   --resume   reuse the most recent run directory instead of creating a new
#              one (e.g. after the job hit its time limit); files that were
#              already downloaded / processed are skipped.
# =========================================================================

set -euo pipefail

CONFIG_FILE="config/default.sh"
RESUME=0
for arg in "$@"; do
    case "${arg}" in
        --resume) RESUME=1 ;;
        *)        CONFIG_FILE="${arg}" ;;
    esac
done

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration: creates a new run directory unless resuming
if [[ "${RESUME}" == "1" ]]; then
    . "${CONFIG_FILE}"
    echo "Resuming in existing run directory: ${BASE_DIR}"
else
    NEW_RUN=1 . "${CONFIG_FILE}"
    echo "Created new run directory: ${BASE_DIR}"
fi

# Create log directory
mkdir -p "${LOG_DIR}"

# Don't start a second downloader in the same run directory: both would
# request (and write) the same files
if [[ "${RUN_MODE}" != "local" && -s "${LOG_DIR}/prep.jobid" ]]; then
    old_jid=$(cat "${LOG_DIR}/prep.jobid")
    if squeue -h -j "${old_jid}" 2>/dev/null | grep -q .; then
        echo "Error: prep job ${old_jid} is still queued/running for ${BASE_DIR}." >&2
        echo "Wait for it to finish or scancel ${old_jid} first." >&2
        exit 1
    fi
fi

# Build account flag only if PROJECT_CODE is non-empty
ACCOUNT_FLAG=()
if [[ -n "${PROJECT_CODE}" ]]; then
    ACCOUNT_FLAG=(--account="${PROJECT_CODE}")
fi

if [[ "${RUN_MODE}" == "local" ]]; then
    echo "Running run_download_and_process.sh locally with config: ${CONFIG_FILE}"
    CONFIG_FILE="${CONFIG_FILE}" RUN_DIR="${BASE_DIR}" \
        bash run_download_and_process.sh >> "${LOG_DIR}/log.run_download_and_process" 2>&1 &
    echo $! > "${LOG_DIR}/prep.pid"
    echo "Started in background. PID: $(cat "${LOG_DIR}/prep.pid")"
    echo "To stop: kill $(cat ${LOG_DIR}/prep.pid)"
    echo "To check progress: tail -f ${LOG_DIR}/log.run_download_and_process"
else
    echo "Submitting run_download_and_process.sh to Slurm with config: ${CONFIG_FILE}"
    jid=$(sbatch --parsable \
        ${ACCOUNT_FLAG[@]+"${ACCOUNT_FLAG[@]}"} \
        -n "${PREP_NTASKS}" \
        -N "${PREP_NNODES}" \
        --cpus-per-task="${PREP_NCPUS}" \
        --mem="${PREP_MEM}" \
        --time="${PREP_TIME}" \
        -o "${LOG_DIR}/log.prep_density_data_%j.out" \
        --job-name="prep_density_data" \
        --export=CONFIG_FILE="${CONFIG_FILE}",RUN_DIR="${BASE_DIR}" \
        run_download_and_process.sh)
    echo "${jid}" > "${LOG_DIR}/prep.jobid"
    echo "Submitted. Job ID: ${jid}"
    echo "To stop: scancel ${jid}"
    echo "To check progress: squeue -j ${jid}"
    echo "Per-request download logs: ${LOG_DIR}/downloads/"
fi
