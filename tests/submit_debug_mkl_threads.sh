#!/usr/bin/env bash
#SBATCH --time=00:05:00
#SBATCH --mem=2G
#SBATCH --output=tests/debug_mkl_%j.out
. config/<your_conda_config>.sh
source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV_NAME}"
hostname
lscpu | grep -E "Model name|MHz|CPU\(s\):"
python debug_mkl_threads.py