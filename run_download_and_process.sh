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

# Environment setup (needed because sbatch shells don't source ~/.bashrc)
if [[ "${ENV_TYPE}" == "venv" ]]; then
    source "${VENV_PATH}/bin/activate"
elif [[ "${ENV_TYPE}" == "conda" ]]; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_NAME}"
fi

# Create output directories
mkdir -p "${LOG_DIR}" "${RAW_DIR}" "${DENSITY_DIR}" "${SPLINE_DIR}" "${MUFLUX_DIR}"

# Kill all background jobs spawned by this script if interrupted
trap 'echo "Interrupted — killing all download/processing jobs for this run..."; kill 0; exit 1' INT TERM

# Function to increment time
--------------------------
function advance_time {
  ccyymmdd=`echo $1 |cut -c1-8`
  hh=`echo $1 |cut -c9-10`
  mm=`echo $1 |cut -c11-12`
  inc=$2
  date -u -d $inc' minutes '$ccyymmdd' '$hh':'$mm +%Y%m%d%H%M
}
#TODO: check if this works
# function advance_time {
#   python -c "from datetime import datetime, timedelta; 
#   print(
#     (datetime.strptime('$1', '%Y%m%d%H%M') + 
#     timedelta(minutes=$2)).strftime('%Y%m%d%H%M')
#   )"
# }


# Function to loop over times requested
# --------------------------------------
function request_date_loop { 

  # Read in name of python script to call
  python_script=$1

  # Starting loop
  date_nw=$date_st

  while [[ $date_nw -le $date_ed ]]; do
    python -u $python_script $date_nw $domain_max_latitude $domain_min_latitude $domain_max_longitude $domain_min_longitude
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
    logfile="${LOG_DIR}/log.${script::-3}"
    echo Running $script
    request_date_loop $script >& $logfile &
done

# Wait for requests to terminate before quitting.
echo Waiting for all scripts to clear. Check log files for progress.
wait

date
echo Finished running downloads


echo ""

date
echo Generating density fields from downloaded data

python compute_era5_density.py  $date_st  $date_ed  $time_interval

echo Finished generating density fields
date