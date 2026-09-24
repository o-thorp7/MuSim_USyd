#!/usr/bin/env bash
#SBATCH --time=00:05:00
#SBATCH --account=PAS2635
#SBATCH --mem=2G
#SBATCH --output=tests/output/debug_mkl_%j.out
. config/sbatch_conda_test.sh
source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
conda activate "${CONDA_ENV_NAME}"
hostname
lscpu | grep -E "Model name|MHz|CPU\(s\):"
python tests/debug_mkl_threads.py