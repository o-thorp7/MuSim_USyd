#!/usr/bin/env python

import numpy as np
import sys
import pandas as pd
import geopy.distance
from scipy import interpolate

import time

def make_3d_spline(fpath):
    atm_data = pd.read_pickle(fpath)
    lons = atm_data['lon']['data']
    lats = atm_data['lat']['data']
    print(lons)
    print(lats)
    hs = atm_data['altitude']['data']
    rhos = atm_data['air_density']['data']
    print(hs, np.shape(hs))

    latdim = np.shape(lats)[0]
    londim = np.shape(lons)[0]
    hdim = np.shape(hs)[0]

    plt_lons = []
    plt_lats = []
    plt_hs = []
    plt_rhos = []

    for ilon in range(0,londim,1):
        for ilat in range(0,latdim,1):
            for ih in range(0,hdim,1):
                thislat = lats[ilat]
                plt_lons.append(lons[ilon])
                plt_lats.append(lats[ilat])
                plt_hs.append(hs[ih][ilat][ilon])
                
                bin_values = rhos[ih][ilat:ilat+1,ilon:ilon+1]
                avgd_field = np.average(bin_values)
                plt_rhos.append(avgd_field)

    plt_lons = np.array(plt_lons)
    plt_lats = np.array(plt_lats)
    plt_hs = np.array(plt_hs)/1000.
    plt_rhos = np.array(plt_rhos)
    my_spline = interpolate.LinearNDInterpolator(list(zip(plt_lats,plt_lons,plt_hs)),plt_rhos, rescale=True)
    return my_spline

def make_slice_spline(phi, latlonhspline, detlon, detlat):
    reg_hs = np.linspace(0,25, 100)

    detpos = geopy.Point(detlat, detlon)

    slice_ls = []
    slice_zs = []
    slice_drhos = []

    for l in np.arange(0.,5000.,10):
        d = geopy.distance.geodesic(kilometers = l)
        dest = d.destination(point=detpos, bearing=phi)

        lon = dest.longitude
        lat = dest.latitude
        
        for h in reg_hs:
            slice_ls.append(l)
            slice_zs.append(h)
            slice_drhos.append(latlonhspline(lat, lon, h))#-latlonhspline(detlat, detlon, h))
    zdrhos = np.array(slice_drhos)

    slice_spline = interpolate.LinearNDInterpolator(list(zip(slice_ls,slice_zs)),zdrhos)
    return slice_spline

def make_avg_spline(phis, splinedict, detlon, detlat):
#    splinedict_filepath = fpath+'slice_splines_%s_%0.3f_%0.3f.npy'%(str(modelnum).zfill(5), detlon, detlat)
#    splinedict_file = np.load(splinedict_filepath, allow_pickle=True)
#    splinedict = splinedict_file.item()

    slice_vals_list = []
    for phi in phis:
        print(phi)
        slice_spline = splinedict[phi]
        xvals = np.linspace(0,5000,100)
        zvals = np.linspace(0,25,100)

        arr_x = []
        arr_z = []
        slicevals = []
        for x in xvals:
            for z in zvals:
                arr_x.append(x)
                arr_z.append(z)
                splineval = slice_spline(x,z)
                if np.isnan(splineval):
                    slicevals.append(0.)
                else:
                    slicevals.append(splineval)
        outarr = np.array([arr_x, arr_z, slicevals])

        plt_x = outarr[0]
        plt_z = outarr[1]
        slicevals = outarr[2]
        slice_vals_list.append(slicevals)

    slice_vals_list = np.array(slice_vals_list)
    slice_avg = np.average(slice_vals_list, axis=0)

    spline_arrs = np.array([plt_x, plt_z, slice_avg])
    return spline_arrs
    #avg_spline = interpolate.LinearNDInterpolator(list(zip(plt_x, plt_z)), slice_avg)
    #return avg_spline


#modelnum = int(sys.argv[1])
this_fpath = str(sys.argv[1])
#phi = float(sys.argv[2])
detlon = float(sys.argv[2])
detlat = float(sys.argv[3])
outfile = str(sys.argv[4])

#this_fpath = '/users/PAS0654/wluszczak/ensda/datafiles/air_density_%s.pkl'%(str(modelnum).zfill(5))
#this_fpath = inputdir+'/reduced_prior_%s.pkl'%(str(modelnum).zfill(5))
#this_fpath = inputdir + '/air_density_%s.pkl'%(str(modelnum).zfill(5))
print("making 3d spline")
print("outfile", outfile)
full_spline = make_3d_spline(this_fpath)
spline_dict = {}
for phi in np.arange(0,360,1):
    print("making spline for phi", phi)
    slice_spline = make_slice_spline(phi, full_spline, detlon, detlat)
    spline_dict[phi]=slice_spline

#    xvals = np.linspace(0,5000,100)
#    zvals = np.linspace(0,25,100)
#
#    arr_x = []
#    arr_z = []
#    slicevals = []
#    for x in xvals:
#        for z in zvals:
#            arr_x.append(x)
#            arr_z.append(z)
#            splineval = slice_spline(x,z)
#            if np.isnan(splineval):
#                slicevals.append(0.)
#            else:
#                slicevals.append(splineval)
#
#    outarr = np.array([arr_x, arr_z, slicevals])
#    combined_outarr.append(outarr)

#combined_outarr = np.array(combined_outarr)
##splinedir = '/users/PAS0654/wluszczak/ensda/splines/'
#splinedir = outdir+'/splines/'
#np.save(splinedir+'slice_spline_%s_%0.3f_%0.3f_%0.3f'%(str(modelnum).zfill(5), phi, detlon, detlat), outarr)

#np.save(splinedir+'slice_splines_%s_%0.3f_%0.3f.npy'%(str(modelnum).zfill(5), detlon, detlat), spline_dict)
phis = np.arange(0,360,1)
avg_spline = make_avg_spline(phis, spline_dict, detlon, detlat)
#fpath = outdir+'/splines/'
#np.save(fpath+'/avg_spline_%s.npy'%(str(modelnum).zfill(5)), avg_spline)
np.save(outfile, avg_spline)
