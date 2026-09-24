#!/usr/bin/env bash
#SBATCH --job-name=test_env
#SBATCH --account=PAS2635
#SBATCH --time=00:02:00
#SBATCH --mem=500M
#SBATCH --output=tests/output/test_env_%j.out

CONFIG_FILE="${CONFIG_FILE:-config/default.sh}"
. "${CONFIG_FILE}"

echo "python BEFORE activation: $(which python 2>&1)"

if [[ "${ENV_TYPE}" == "venv" ]]; then
    source "${VENV_PATH}/bin/activate"
elif [[ "${ENV_TYPE}" == "conda" ]]; then
    source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_NAME}"
fi

echo "python AFTER activation: $(which python 2>&1)"
python -c "import numpy, netCDF4, scipy; print('numpy/netCDF4/scipy import OK')"