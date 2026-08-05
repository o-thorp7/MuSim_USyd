#!/usr/bin/bash

#SBATCH --job-name=muflux_calc_$1_$2
#SBATCH --mem=5gb
#SBATCH --time=1:00:00

echo "starting muflux calc" $1 $2
#cd /users/PAS0654/wluszczak/ensda/
python3 muflux_calc.py $1 $2 $3
echo "finished spline for" $1 $2
