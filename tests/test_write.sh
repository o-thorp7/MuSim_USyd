#!/usr/bin/env bash
#SBATCH --job-name=test_write
#SBATCH --account=PAS2635
#SBATCH --time=00:01:00
#SBATCH --mem=50M
#SBATCH --output=tests/output/test_write_%j.out

CONFIG_FILE="${CONFIG_FILE:-config/default.sh}"
. "${CONFIG_FILE}"

testfile="${LOG_DIR}/test_write_${SLURM_JOB_ID}.txt"
mkdir -p "${LOG_DIR}"
echo "written by job ${SLURM_JOB_ID} on $(hostname) at $(date)" > "${testfile}"
echo "wrote to: ${testfile}"
cat "${testfile}"