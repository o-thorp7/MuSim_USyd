#!/usr/bin/env bash
# =========================================================================
# Bash script to call down ERA5 10-member ensemble and ERA5 control member
# -------------------------------------------------------------------------
# Written by Man-Yau (Joseph) Chan
# =========================================================================

# Get config file from environment variable (set by sbatch --export)
# or from first argument (if run locally), default to config/default.sh
CONFIG_FILE="${CONFIG_FILE:-${1:-config/default.sh}}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

# Override the config date range when submit_prep_density_data.sh passes a chunk
this_date_st="${JOB_DATE_ST:-${date_st}}"
this_date_ed="${JOB_DATE_ED:-${date_ed}}"

FAILED_FILE="${LOG_DIR}/failed_downloads_${this_date_st}.txt"
rm -f "${FAILED_FILE}"

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
mkdir -p "${LOG_DIR}" "${RAW_DIR}" "${DENSITY_DIR}" "${SPLINE_DIR}" "${MUFLUX_DIR}"

# Function to increment time
# --------------------------
function advance_time {
  ccyymmdd=`echo $1 |cut -c1-8`
  hh=`echo $1 |cut -c9-10`
  mm=`echo $1 |cut -c11-12`
  inc=$2
  date -u -d $inc' minutes '$ccyymmdd' '$hh':'$mm +%Y%m%d%H%M
}


# Function to loop over times requested
# --------------------------------------
function request_date_loop { 

  # Read in name of python script to call
  python_script=$1

  # Starting loop
  date_nw=$this_date_st

  while [[ $date_nw -le $this_date_ed ]]; do
    python -u $python_script $date_nw $domain_max_latitude $domain_min_latitude $domain_max_longitude $domain_min_longitude \
        || echo "$python_script $date_nw" >> "${FAILED_FILE}"
    date_nw=`advance_time $date_nw $time_interval`  
  done
}



# MAIN PROGRAM
# -------------

# Opening message
date
echo Starting to run downloads with config: ${CONFIG_FILE}

# Loop over scripts to run
for script in $download_script_list; do
    logfile="${LOG_DIR}/log.${script::-3}_${this_date_st}"
    echo "Running ${script} starting at ${this_date_st}"
    request_date_loop $script >& $logfile &
done

# Wait for requests to terminate before quitting.
echo Waiting for all scripts to clear. Check log files for progress.
wait

date
echo Finished running downloads


echo ""

if [[ -s "${FAILED_FILE}" ]]; then
    echo "Some downloads failed (see ${FAILED_FILE}); skipping density step"
    exit 1
fi


date
echo Generating density fields from downloaded data

python compute_era5_density.py $this_date_st $this_date_ed $time_interval || { echo "density step failed"; exit 1; }

echo Finished generating density fields
date