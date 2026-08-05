#!/usr/bin/bash

#SBATCH --job-name=slice_spline_$1_$2_$3_$4
#SBATCH --mem=10gb
#SBATCH --time=4:00:00

echo "starting slice spline" $1 $2 $3 $4
python3 make_slice_spline.py $1 $2 $3 $4
echo "finished spline for" $1 $2 $3 $4

