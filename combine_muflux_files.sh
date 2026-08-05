#!/bin/bash
#
# Submits one Slurm job per density_era5_hires_*.pkl file, running
# make_slice_spline.py and writing a uniquely-named output spline.
#
# Usage:
#   ./submit_splines.sh
#
# Adjust LON, LAT, and the sbatch resource flags as needed.

set -euo pipefail

# --- Fixed arguments for every job ---
LON=151.1873
LAT=-33.8886

# --- Directories ---
INPUT_DIR="splines"          # where the .pkl files live
OUTPUT_DIR="mufluxes"   # where the .npy outputs go
mkdir -p "${OUTPUT_DIR}"

# --- Slurm resource settings (edit to match your cluster) ---
TIME="00:30:00"
MEM="4G"
CPUS=1
OSC_ACC=PAS2635

# Match files like: density_era5_hires_2026-06-09_03UTC.pkl
shopt -s nullglob
FILES=("${INPUT_DIR}"/avg_spline_*.npy)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No matching .pkl files found in ${INPUT_DIR}" >&2
    exit 1
fi

for f in "${FILES[@]}"; do
    fname=$(basename "${f}")

    # Extract the timestamp (e.g. 2026-06-09_03UTC) from the filename
    if [[ "${fname}" =~ avg_spline_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}UTC)\.npy$ ]]; then
        timestamp="${BASH_REMATCH[1]}"
    else
        echo "Skipping unrecognized filename format: ${fname}" >&2
        continue
    fi

    echo "combining files for" ${timestamp}
    python3 combine_muflux_files.py ${timestamp} .

done
