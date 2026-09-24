#!/usr/bin/env bash
#SBATCH --job-name=test_concurrent
#SBATCH --account=PAS2635
#SBATCH --time=00:01:00
#SBATCH --mem=100M
#SBATCH --output=tests/output/test_concurrent_%j.out

CONFIG_FILE="${CONFIG_FILE:-config/default.sh}"
. "${CONFIG_FILE}"
mkdir -p "${LOG_DIR}/concurrent_test"

sleep $((RANDOM % 5))
echo "job ${SLURM_JOB_ID}" > "${LOG_DIR}/concurrent_test/file_${SLURM_JOB_ID}.txt"