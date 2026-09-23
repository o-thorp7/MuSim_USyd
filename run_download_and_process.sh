#!/bin/bash
# =========================================================================
# Bash script to call down ERA5 10-member ensemble and ERA5 control member
# -------------------------------------------------------------------------
# Written by Man-Yau (Joseph) Chan
# =========================================================================

# Load configuration
. config.sh


# Function to increment time
# --------------------------
# function advance_time {
#   ccyymmdd=`echo $1 |cut -c1-8`
#   hh=`echo $1 |cut -c9-10`
#   mm=`echo $1 |cut -c11-12`
#   inc=$2
#   date -u -d $inc' minutes '$ccyymmdd' '$hh':'$mm +%Y%m%d%H%M
# }
function advance_time {
  python -c "from datetime import datetime, timedelta; " \
            "print(" \
                "(datetime.strptime('$1', '%Y%m%d%H%M') + " \
                "timedelta(minutes=$2)).strftime('%Y%m%d%H%M')" \
            ")"
}


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
echo Starting to run downloads

# Loop over scripts to run
for script in $download_script_list; do
    logfile=log.${script::-3}
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