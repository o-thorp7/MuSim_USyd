#!/usr/bin/env bash
#SBATCH --job-name=test_basic
#SBATCH --account=PAS2635
#SBATCH --time=00:01:00
#SBATCH --mem=100M
#SBATCH --output=tests/output/test_basic_%j.out

echo "host: $(hostname)"
echo "job id: $SLURM_JOB_ID"
echo "job name: $SLURM_JOB_NAME"
echo "requested mem: $SLURM_MEM_PER_NODE MB"
echo "requested time limit:"
scontrol show job $SLURM_JOB_ID | grep -i timelimit
echo "sleeping for 5 seconds"
sleep 5
echo "done"