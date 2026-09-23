#!/usr/bin/env python
import numpy as np
import sys
import os
from pathlib import Path

def integrate_flux(egrid, fluxarr):
    dbins = np.diff(egrid)
    nint = np.sum(fluxarr[:-1]*dbins)
    return nint

def get_sigflux(th, e_grid, fpath, timestamp):
    th = int(th)
    data = np.load(fpath / f'muflux_{timestamp}_{th}.npy')
    dataint = integrate_flux(e_grid, data)
    tot = dataint
    return tot

def get_one_curve(e_grid, fpath, timestamp):
    theta_min = float(os.environ.get('THETA_MIN', 5))
    theta_max = float(os.environ.get('THETA_MAX', 81))
    theta_step = float(os.environ.get('THETA_STEP', 5))
    ths = np.arange(theta_min, theta_max, theta_step)
    
    all_ys = []
    all_ths = []
    all_dfluxs = []
    thind=0
    for th in ths[:-1]:
        sigflux = get_sigflux(th, e_grid, fpath, timestamp)*(np.cos(np.radians(ths[thind]))-np.cos(np.radians(ths[thind+1])))*2*np.pi*1e4# per second per m^2
        all_ths.append(90.-th)
        all_dfluxs.append(sigflux)
        thind+=1
    all_ths = np.array(all_ths)
    all_dfluxs = np.array(all_dfluxs)
    return np.array([all_ths, all_dfluxs])

timestamp = str(sys.argv[1])
fpath = Path(sys.argv[2])
e_grid = np.load(fpath / "egrid.npy")

combined_data = get_one_curve(e_grid, fpath, timestamp)
np.save(fpath / f'combined_muflux_{timestamp}.npy', combined_data)