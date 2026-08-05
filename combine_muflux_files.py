#!/usr/bin/env python
import numpy as np
import sys

def integrate_flux(egrid, fluxarr):
    dbins = np.diff(egrid)
    nint = np.sum(fluxarr[:-1]*dbins)
    return nint

def get_sigflux(th, e_grid, fpath, timestamp):
    th = int(th)
    data = np.load(fpath+'/mufluxes/muflux_%s_%s.npy'%(timestamp, th))
    dataint = integrate_flux(e_grid, data)
    tot = dataint
    return tot

def get_one_curve(e_grid, fpath, timestamp):
    ths = np.arange(5.0,81.0,5.0)
    all_ys = []
    all_ths = []
    all_dfluxs = []
    thind=0
    for th in ths[:-1]:
#        if th==65:
#            pass
#        else:
        sigflux = get_sigflux(th, e_grid, fpath, timestamp)*(np.cos(np.radians(ths[thind]))-np.cos(np.radians(ths[thind+1])))*2*np.pi*1e4# per second per m^2
        all_ths.append(90.-th)
        all_dfluxs.append(sigflux)
        thind+=1
    all_ths = np.array(all_ths)
    all_dfluxs = np.array(all_dfluxs)
    return np.array([all_ths, all_dfluxs])

timestamp = str(sys.argv[1])
fpath = str(sys.argv[2])
e_grid = np.load('egrid.npy')
combined_data = get_one_curve(e_grid, fpath, timestamp)
np.save(fpath+'/mufluxes/combined_muflux_%s.npy'%(timestamp), combined_data)
