#!/bin/bash
# =========================================================================
# Configuration controlling ERA5 downloads and density calculations
# -------------------------------------------------------------------------
# Written by Man-Yau (Joseph) Chan
# =========================================================================

# Dates of interest
# ------------------
date_st=202606090000    # First date of interest
date_ed=202606091200    # Last date of interest
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


# =========================================================================
# RUNTIME CONFIGURATION — all paths and resource settings below
# =========================================================================

# Config identity — compute BASE_DIR from this script's location
# ---------------------------------------------------------------
CONFIG_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"
BASE_DIR="${REPO_ROOT}/../musim_outputs/${CONFIG_NAME}"

# Run mode: "sbatch" submits to Slurm, "local" runs directly via bash/python
# ---------------------------------------------------------------------------
RUN_MODE="sbatch"

# Slurm account / resources
# --------------------------
PROJECT_CODE=""            # e.g. "highen" — leave blank if not required
PREP_NTASKS=4
PREP_NNODES=1
PREP_TIME="01:00:00"
SPLINE_TIME="04:00:00"
SPLINE_MEM="10G"
MUFLUX_TIME="01:00:00"
MUFLUX_MEM="5G"

# Python environment
# -------------------
ENV_TYPE="venv"             # "venv" or "conda"
VENV_PATH="${HOME}/musim_env"
CONDA_ENV_NAME="musim"

# Detector location + zenith angle scan
# ---------------------------------------
LON=151.1873
LAT=-33.8886
THETA_MIN=5
THETA_MAX=81
THETA_STEP=5

# Output directories (all derived from BASE_DIR)
# -----------------------------------------------
LOG_DIR="${BASE_DIR}/logs"
ERA5_RAW_DIR="${BASE_DIR}/raw"
ERA5_DENSITY_DIR="${BASE_DIR}/density"
SPLINE_DIR="${BASE_DIR}/splines"
MUFLUX_DIR="${BASE_DIR}/mufluxes"

# Export for use by Python scripts
export ERA5_RAW_DIR ERA5_DENSITY_DIR THETA_MIN THETA_MAX THETA_STEP