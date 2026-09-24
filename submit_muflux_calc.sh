#!/usr/bin/env bash
#SBATCH --mem=1gb          # Default fall-back directive values in case command-line flags fail
#SBATCH --time=00:15:00

# Get config file from environment variable (set by sbatch --export)
# or from first argument (if run locally), default to config/default.sh
CONFIG_FILE="${CONFIG_FILE:-${1:-config/default.sh}}"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "Error: Config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# Load configuration
. "${CONFIG_FILE}"

# Environment setup (needed because sbatch shells don't source ~/.bashrc)
if [[ "${ENV_TYPE}" == "venv" ]]; then
    source "${VENV_PATH}/bin/activate"
elif [[ "${ENV_TYPE}" == "conda" ]]; then
    source "${CONDA_BASE_PATH}/etc/profile.d/conda.sh"
    conda activate "${CONDA_ENV_NAME}"
fi

echo "starting muflux calc" $1 $2
python3 muflux_calc.py $1 $2 $3
echo "finished muflux calc for" $1 $2