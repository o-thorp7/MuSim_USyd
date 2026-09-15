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
# added by oli
# INPUT_DIR="density_era5_hires"
INPUT_DIR="."          # where the .pkl files live
OUTPUT_DIR="splines"   # where the .npy outputs go
mkdir -p "${OUTPUT_DIR}"

# --- Slurm resource settings (edit to match your cluster) ---
TIME="00:30:00"
MEM="4G"
CPUS=1
OSC_ACC=PAS2635

# Match files like: density_era5_hires_2026-06-09_03UTC.pkl
shopt -s nullglob
FILES=("${INPUT_DIR}"/density_era5_hires_*.pkl)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
    echo "No matching .pkl files found in ${INPUT_DIR}" >&2
    exit 1
fi

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

    echo "Submitting job for ${fname} -> ${outfile}"

    # added by oli:
    bash submit_slice_spline.sh "${f}" "${LON}" "${LAT}" "${outfile}" > "logs/${jobname}.out" 2> "logs/${jobname}.err"
    # sbatch --account=$OSC_ACC --output="logs/${jobname}_%j.out" --error="logs/${jobname}_%j.err" submit_slice_spline.sh ${f} ${LON} ${LAT} ${outfile}
done
