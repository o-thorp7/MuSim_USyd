#!/usr/bin/env python

import numpy as np
import pandas as pd
from scipy import interpolate

lon = 151.0293
lat = -33.8688

ts = []
true_psfcs = []
for t in np.arange(100,2400,100):
    print(t)
    tstr = str(t).zfill(4)
    hr = str(t//100+1).zfill(2)

    psfcfile = '20210320/truthfile_20210320%s_v2.pkl'%(tstr)

    truthdata = pd.read_pickle(psfcfile)
    psfc = truthdata['surface pressure']
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

outarr = [ts, true_psfcs]
outarr = np.array(outarr)
np.save('true_psfcs_20210320.npy', outarr)
