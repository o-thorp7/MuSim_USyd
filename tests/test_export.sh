#!/usr/bin/env bash
#SBATCH --job-name=test_export
#SBATCH --account=PAS2635
#SBATCH --time=00:01:00
#SBATCH --mem=100M
#SBATCH --output=tests/output/test_export_%j.out

echo "CONFIG_FILE received: ${CONFIG_FILE:-NOT SET}"