#!/usr/bin/env python
from scipy.interpolate import RegularGridInterpolator
import re
import sys
import numpy as np
import glob
from pathlib import Path
import pandas as pd

config_lon = float(sys.argv[1])
config_lat = float(sys.argv[2])
hires_dir = Path(sys.argv[3])
ens_dir = Path(sys.argv[4])
muflux_dir = Path(sys.argv[5])
base_dir = Path(sys.argv[6])

output_dir = base_dir / "summary"
output_dir.mkdir(parents=True, exist_ok=True)


def point_value(lat1d, lon1d, psfc, method="cubic"):
    # psfc is (lat, lon); raises if the point is outside the domain
    f = RegularGridInterpolator((lat1d, lon1d), np.asarray(psfc), method=method, bounds_error=True)
    return float(f((config_lat, config_lon)))

def stamp(p):
    return re.search(r"\d{4}-\d{2}-\d{2}_\d{2}", Path(p).name).group()

mufluxes = {stamp(p): p for p in muflux_dir.glob("combined*.npy")}
hires = {stamp(p): p for p in hires_dir.glob("*.pkl")}
ens   = {stamp(p): p for p in ens_dir.glob("*.pkl")}
if hires.keys() != ens.keys() or hires.keys() != mufluxes.keys():
    raise ValueError("Error: timestamps in hires, ens, or mufluxes do not match; only using common timestamps")
stamps = sorted(hires.keys())
times = np.array([pd.to_datetime(s, format="%Y-%m-%d_%H") for s in stamps])

mufluxes_all = []
hires_psfcs = []
ens_psfcs = []

for s in stamps:
    mufluxes_all.append(np.load(mufluxes[s]))

    hires_data = pd.read_pickle(hires[s])
    h_lat, h_lon, h_psfc = hires_data["lat"]["data"], hires_data["lon"]["data"], hires_data["psfc"]["data"]
    hires_psfcs.append(point_value(h_lat, h_lon, h_psfc))
    
    ens_data = pd.read_pickle(ens[s])
    e_lat, e_lon, e_psfc = ens_data["lat"]["data"], ens_data["lon"]["data"], ens_data["psfc"]["data"]
    s_ens_psfcs = []
    for i in range(e_psfc.shape[0]):
        s_ens_psfcs.append(point_value(e_lat, e_lon, e_psfc[i]))
    ens_psfcs.append(np.array(s_ens_psfcs))

np.save(output_dir / "combined_times.npy", np.array(times))
np.save(output_dir / "combined_mufluxes.npy", np.array(mufluxes_all))
np.save(output_dir / "hires_psfc.npy", np.array(hires_psfcs))
np.save(output_dir / "ens_psfc.npy", np.array(ens_psfcs).T)