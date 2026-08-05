''' Script to request for ERA-5 reanalysis data within a limited area for a limited time '''

#import cdsapi
from cdsapi import Client
import numpy as np
import datetime
import sys

# Date to request
date = datetime.datetime.strptime( sys.argv[1], '%Y%m%d%H%M')

# Read in lat-lon range of data to request
max_lat=float( sys.argv[2] )
min_lat=float( sys.argv[3] )
max_lon=float( sys.argv[4] )
min_lon=float( sys.argv[5] )


c = Client()

c.retrieve(
    'reanalysis-era5-single-levels',
    {
        'product_type':'ensemble_members',
        'format':'netcdf',
        'variable': ['2m_dewpoint_temperature','2m_temperature', 'geopotential',
                    'surface_pressure'],
        'area': [max_lat, min_lon, min_lat, max_lon],  # N, W, S, E
        'year':date.strftime('%Y'),
        'month':date.strftime('%m'),
        'day': date.strftime('%d'),
        'time': date.strftime('%H')
    },
    'era5_ensem_land_' + date.strftime('%Y-%m-%d_%H')+'UTC.nc')
