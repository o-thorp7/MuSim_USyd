#!/usr/bin/env python

import numpy as np
import pandas as pd
from scipy import interpolate

from datetime import datetime
from pathlib import Path

import glob
import os
import sys


lon = float(sys.argv[1])
lat = float(sys.argv[2])
density_dir = Path(sys.argv[3])
muflux_dir = Path(sys.argv[4])
base_dir = Path(sys.argv[5])

output_dir = base_dir / "summary"
output_dir.mkdir(parents=True, exist_ok=True)



# folder = Path("local_venv_test_results/density/era5_ensem/")
psfc_files = sorted(glob.glob(str(density_dir / "*.pkl")))
comb_muflux_files = sorted(glob.glob(str(muflux_dir / "combined*.npy")))

ts = []
comb_mufluxes = []
for comb_muflux_file in comb_muflux_files:
    # assumes formatted like combined_muflux_2026-06-09_06UTC.npy
    t = datetime.strptime(comb_muflux_file[-20:-7], "%Y-%m-%d_%H")
    comb_mufluxes.append(np.load(comb_muflux_file))
    ts.append(t)

np.save(output_dir / "combined_times.npy", np.array(ts))
np.save(output_dir / "combined_mufluxes.npy", np.array(comb_mufluxes))


# for t in np.arange(100,2400,100):
    # print(t)
    # tstr = str(t).zfill(4)
    # hr = str(t//100+1).zfill(2)
    # psfcfile = '20210320/truthfile_20210320%s_v2.pkl'%(tstr)

true_psfcs = []

for psfcfile in psfc_files:
    # assumes formatted like density_era5_ensem_2026-06-09_12UTC.pkl
    t = datetime.strptime(psfcfile[-20:-7], "%Y-%m-%d_%H")

    truthdata = pd.read_pickle(psfcfile)
    psfc = truthdata['surface pressure'] #TODO: fix key error
    londata = truthdata['longitude (deg E)']
    latdata = truthdata['latitude (deg N)']
    print(np.min(londata), np.max(londata), (np.min(londata)+np.max(londata))/2)
    print(np.min(latdata), np.max(latdata), (np.min(latdata)+np.max(latdata))/2)

    latdim = np.shape(londata)[0]
    londim = np.shape(londata)[1]

    plt_lons = []
    plt_lats = []
    plt_rhos = []

    for ilon in range(0,londim):
        for ilat in range(0,latdim):
            thislat = latdata[ilat][ilon]
            thislon = londata[ilat][ilon]
            thisrho = psfc[ilat][ilon]

            plt_lons.append(thislon)
            plt_lats.append(thislat)
            plt_rhos.append(thisrho)

    plt_lons = np.array(plt_lons)
    plt_lats = np.array(plt_lats)
    plt_rhos = np.array(plt_rhos)
    my_spline = interpolate.LinearNDInterpolator(list(zip(plt_lats,plt_lons)), plt_rhos, rescale=True)
    truth_psfc = my_spline(lat, lon)

    true_psfcs.append(truth_psfc)
    ts.append(t)

# outarr = [ts, true_psfcs]
# outarr = np.array(outarr)
# np.save('true_psfcs_20210320.npy', outarr)
np.save(output_dir / "combined_psfc.npy", np.array(true_psfcs))
