#!/usr/bin/bash

# Load configuration
. config.sh

# Environment setup (needed because sbatch shells don't source ~/.bashrc)
if [[ "${ENV_TYPE}" == "venv" ]]; then
    source "${VENV_PATH}/bin/activate"
elif [[ "${ENV_TYPE}" == "conda" ]]; then
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_NAME}"
fi

#SBATCH --job-name=muflux_calc_$1_$2
#SBATCH --mem=5gb
#SBATCH --time=1:00:00

echo "starting muflux calc" $1 $2
python3 muflux_calc.py $1 $2 $3
echo "finished muflux calc for" $1 $2