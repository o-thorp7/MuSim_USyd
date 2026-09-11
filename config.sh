#!/bin/bash
# =========================================================================
# Configuration controlling ERA5 downloads and density calculations
# -------------------------------------------------------------------------
# Written by Man-Yau (Joseph) Chan
# =========================================================================

# Dates of interest
# ------------------
# date_st=202606090000    # First date of interest
# date_ed=202606140000    # Last date of interest
date_st=202606230000    # First date of interest
date_ed=202606240000    # Last date of interest
time_interval=180       # Number of minutes between files to download


# Region of interest (currently: Sydney, Australia)
# -------------------------------------------------
domain_min_latitude=-35.0  # In degrees North
domain_max_latitude=-32.0  # In degrees North
domain_min_longitude=150.0 # In degrees East
domain_max_longitude=152.0 # In degrees East


# Download scripts to run
# -----------------------
download_script_list="download_era5_hires_land.py  download_era5_hires_plvl.py  download_era5_ensem_land.py  download_era5_ensem_plvl.py"
