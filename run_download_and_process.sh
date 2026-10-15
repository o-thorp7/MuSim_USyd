#!/usr/bin/env bash
# =========================================================================
# Bash script to call down ERA5 10-member ensemble and ERA5 control member
# -------------------------------------------------------------------------
# Written by Man-Yau (Joseph) Chan
# =========================================================================
#
# Downloads every (script, time) pair in the configured date range, keeping
# at most MAX_CDS_REQUESTS CDS requests in flight at once, then computes
# density fields. Each request is retried up to CDS_MAX_ATTEMPTS times.
#
# Resumable: files that already exist are skipped (downloads are written to
# a .part file and only renamed once complete), so if the job hits its time
# limit, rerun ./submit_prep_density_data.sh <config> --resume.

# Get config file from environment variable (set by sbatch --export)
# or from first argument (if run locally), default to config/default.sh
CONFIG_FILE="${CONFIG_FILE:-${1:-config/default.sh}}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration (uses RUN_DIR passed in by submit_prep_density_data.sh)
. "${CONFIG_FILE}" || exit 1

# Defaults for configs that don't set the throttling options
MAX_CDS_REQUESTS="${MAX_CDS_REQUESTS:-20}"
CDS_MAX_ATTEMPTS="${CDS_MAX_ATTEMPTS:-5}"
CDS_RETRY_WAIT="${CDS_RETRY_WAIT:-300}"

# Environment setup (needed because sbatch shells don't source ~/.bashrc)
if [[ "${ENV_TYPE}" == "venv" ]]; then
    source "${VENV_PATH}/bin/activate"
elif [[ "${ENV_TYPE}" == "conda" ]]; then
    source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_NAME}"
fi

echo "python location: "
which python

# Create output directories
DOWNLOAD_LOG_DIR="${LOG_DIR}/downloads"
mkdir -p "${LOG_DIR}" "${DOWNLOAD_LOG_DIR}" "${RAW_DIR}" "${DENSITY_DIR}" "${SPLINE_DIR}" "${MUFLUX_DIR}"

FAILED_FILE="${LOG_DIR}/failed_downloads.txt"
: > "${FAILED_FILE}"

# Function to increment time
# --------------------------
function advance_time {
  ccyymmdd=`echo $1 |cut -c1-8`
  hh=`echo $1 |cut -c9-10`
  mm=`echo $1 |cut -c11-12`
  inc=$2
  date -u -d $inc' minutes '$ccyymmdd' '$hh':'$mm +%Y%m%d%H%M
}


# Function to download one file, retrying on failure
# ----------------------------------------------------
# Success is judged by the python exit code: the download scripts exit 0 only
# once the file has been fully written (or already existed).
function download_with_retry {
  local python_script=$1 date_nw=$2 attempt wait_s
  local logfile="${DOWNLOAD_LOG_DIR}/${python_script%.py}_${date_nw}.log"

  for (( attempt = 1; attempt <= CDS_MAX_ATTEMPTS; attempt++ )); do
    echo "=== attempt ${attempt} at $(date)" >> "${logfile}"
    if python -u "${python_script}" "${date_nw}" \
         "${domain_max_latitude}" "${domain_min_latitude}" \
         "${domain_max_longitude}" "${domain_min_longitude}" >> "${logfile}" 2>&1; then
      return 0
    fi

    wait_s=$(( CDS_RETRY_WAIT * attempt ))
    # Queue full: back off for longer so the queue can drain
    if grep -q "Number of queued requests is limited" "${logfile}"; then
      wait_s=$(( wait_s * 2 ))
      echo "CDS queue full for ${python_script} ${date_nw}; waiting ${wait_s} s" >&2
    fi
    if (( attempt < CDS_MAX_ATTEMPTS )); then
      echo "=== failed; retrying in ${wait_s} s" >> "${logfile}"
      sleep "${wait_s}"
    fi
  done

  echo "${python_script} ${date_nw}" >> "${FAILED_FILE}"
  echo "GAVE UP on ${python_script} ${date_nw} after ${CDS_MAX_ATTEMPTS} attempts (see ${logfile})" >&2
  return 1
}


# Block until fewer than MAX_CDS_REQUESTS downloads are running
# -------------------------------------------------------------
function wait_for_request_slot {
  while (( $(jobs -rp | wc -l) >= MAX_CDS_REQUESTS )); do
    sleep 10
  done
}



# MAIN PROGRAM
# -------------

# Opening message
date
echo "Starting to run downloads with config: ${CONFIG_FILE}"
echo "Run directory: ${BASE_DIR}"
echo "At most ${MAX_CDS_REQUESTS} CDS requests in flight. Per-request logs in ${DOWNLOAD_LOG_DIR}"

pids=()

for script in $download_script_list; do
    logfile="${LOG_DIR}/log.${script::-3}"
    echo "Running ${script}"
    request_date_loop "${script}" >& "${logfile}" &
    pids+=("$!")
done

echo "Waiting for all download processes to finish."

download_failed=0

for pid in "${pids[@]}"; do
    wait "${pid}" || download_failed=1
done

if [[ "${download_failed}" -ne 0 ]]; then
    echo "At least one ERA5 download process failed." >&2
    echo "Density generation was not started." >&2
    exit 1
fi
# # Loop over scripts to run
# for script in $download_script_list; do
#     logfile="${LOG_DIR}/log.${script::-3}"
#     echo Running $script
#     request_date_loop $script >& $logfile &
# done

# # Wait for requests to terminate before quitting.
# echo Waiting for all scripts to clear. Check log files for progress.
# wait

date
echo Finished running downloads

if [[ -s "${FAILED_FILE}" ]]; then
    echo "WARNING: $(wc -l < "${FAILED_FILE}") download(s) failed; see ${FAILED_FILE}."
    echo "Density will be computed for the complete time steps only."
    echo "Rerun with --resume to retry just the missing files."
fi

echo ""

date
echo Generating density fields from downloaded data

python compute_era5_density.py $date_st $date_ed $time_interval || { echo "density step failed"; exit 1; }

echo Finished generating density fields
date

# Fail the job if anything is missing so it shows up in sacct
[[ ! -s "${FAILED_FILE}" ]]
