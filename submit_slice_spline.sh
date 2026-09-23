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

#SBATCH --job-name=slice_spline_$1_$2_$3_$4
#SBATCH --mem=10gb
#SBATCH --time=4:00:00

echo "starting slice spline" $1 $2 $3 $4
python3 make_slice_spline.py $1 $2 $3 $4
echo "finished spline for" $1 $2 $3 $4