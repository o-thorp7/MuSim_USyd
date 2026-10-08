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

# Load configuration and throttle function
. "${CONFIG_FILE}"
. "$(dirname "${BASH_SOURCE[0]}")/throttle.sh"

# Create log directory
mkdir -p "${LOG_DIR}"

# Build account flag only if PROJECT_CODE is non-empty
ACCOUNT_FLAG=()
if [[ -n "${PROJECT_CODE}" ]]; then
    ACCOUNT_FLAG=(--account="${PROJECT_CODE}")
fi


# Advance a YYYYMMDDHHMM timestamp by N minutes
advance_time() {
    local ccyymmdd="${1:0:8}" hh="${1:8:2}" mm="${1:10:2}"
    date -u -d "$2 minutes ${ccyymmdd} ${hh}:${mm}" +%Y%m%d%H%M
}

# Each job covers num_interval time steps, spaced time_interval minutes apart.
# The last step in a chunk is (num_interval - 1) * time_interval after its start,
# and the next chunk starts num_interval * time_interval after this one's start.
chunk_span=$(( num_interval * time_interval ))
chunk_last_offset=$(( (num_interval - 1) * time_interval ))

: > "${LOG_DIR}/prep.jobids"
: > "${LOG_DIR}/prep.pids"

chunk_st="${date_st}"
while [[ "${chunk_st}" -le "${date_ed}" ]]; do
    chunk_ed="$(advance_time "${chunk_st}" "${chunk_last_offset}")"
    if [[ "${chunk_ed}" -gt "${date_ed}" ]]; then
        chunk_ed="${date_ed}"
    fi

    wait_for_slot "prep_density_"

    if [[ "${RUN_MODE}" == "local" ]]; then
        echo "Running run_download_and_process.sh locally for ${chunk_st} -> ${chunk_ed} with config: ${CONFIG_FILE}"
        CONFIG_FILE="${CONFIG_FILE}" JOB_DATE_ST="${chunk_st}" JOB_DATE_ED="${chunk_ed}" \
            bash run_download_and_process.sh >& "${LOG_DIR}/log.run_download_and_process_${chunk_st}_${chunk_ed}" &
        echo $! >> "${LOG_DIR}/prep.pids"
    else
        echo "Submitting run_download_and_process.sh to Slurm for ${chunk_st} -> ${chunk_ed} with config: ${CONFIG_FILE}"
        jid=$(sbatch --parsable \
            ${ACCOUNT_FLAG[@]+"${ACCOUNT_FLAG[@]}"} \
            -n "${PREP_NTASKS}" \
            -N "${PREP_NNODES}" \
            --cpus-per-task="${PREP_NCPUS}" \
            --mem="${PREP_MEM}" \
            --time="${PREP_TIME}" \
            -o "${LOG_DIR}/log.prep_density_data_${chunk_st}_${chunk_ed}_%j.out" \
            --job-name="prep_density_${chunk_st}" \
            --export=ALL,CONFIG_FILE="${CONFIG_FILE}",JOB_DATE_ST="${chunk_st}",JOB_DATE_ED="${chunk_ed}" \
            run_download_and_process.sh)
        echo "${jid}" >> "${LOG_DIR}/prep.jobids"
        echo "  Job ID: ${jid}"
    fi

    chunk_st="$(advance_time "${chunk_st}" "${chunk_span}")"
done

if [[ "${RUN_MODE}" == "local" ]]; then
    echo "Started $(wc -l < "${LOG_DIR}/prep.pids") background jobs. PIDs in ${LOG_DIR}/prep.pids"
    echo "To stop: xargs kill < ${LOG_DIR}/prep.pids"
    echo "To check progress: tail -f ${LOG_DIR}/log.run_download_and_process_*"
else
    echo "Submitted $(wc -l < "${LOG_DIR}/prep.jobids") jobs. Job IDs in ${LOG_DIR}/prep.jobids"
    echo "To stop: xargs scancel < ${LOG_DIR}/prep.jobids"
    echo "To check progress: squeue -j $(paste -sd, "${LOG_DIR}/prep.jobids")"
fi