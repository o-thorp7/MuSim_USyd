'''
    Script to compute atmospheric densities from ERA5 data
'''

# Standard packages
import numpy as np
from netCDF4 import Dataset as ncopen
from sys import argv
from datetime import datetime, timedelta
from copy import deepcopy
import pickle
import os
from pathlib import Path




''' Settings and Preamble '''

# Command-line specifications
date_st = datetime.strptime( argv[1], '%Y%m%d%H%M' )
date_ed = datetime.strptime( argv[2], '%Y%m%d%H%M' )
time_interval = timedelta( minutes = int(argv[3] ) )

# Get directories from environment
RAW_DIR = Path(os.environ.get('ERA5_RAW_DIR', '.'))
DENSITY_DIR = Path(os.environ.get('ERA5_DENSITY_DIR', '.'))

# ERA5 file prefixes to process
era5_prefix_list = [ 'era5_ensem', 'era5_hires']
era5_ztype_dict = {'plvl': 'plvl', 'land': 'land'}


# List of dates to process
date_list = []
date_nw = deepcopy( date_st )
while date_nw <= date_ed:
    date_list.append(date_nw)
    date_nw += time_interval



''' Function to compute density using moist air gas law '''
def compute_density( temperature, pressure, specific_humidity ):

    epsilon = (461.-287.)/287.
    virt_temperature = temperature * (1. + epsilon * specific_humidity)

    return pressure / ( 287. * virt_temperature)


''' Function to compute eqbm vapor pressure over flat liquid-vapor interface 
        Based on Bohren & Albrecht Thermo textbook Eq 5.67 on pg 308.
'''
def compute_e_sat( temperature ):
    return 611. * np.exp( 6808*(1/273.16 - 1/temperature) - 5.09 * np.log( temperature / 273.16) )


''' Function to convert dewpoint to specific humidity '''
def dewpt_to_spechum( dewpoint, pressure ):
    vap_pres = compute_e_sat( dewpoint )
    spechum = 0.622*vap_pres / (pressure - 0.378*vap_pres )
    return spechum




''' Function to generate density data '''
def compute_density_from_era5_file( file_prefix, ztype_dict, date_targ ):

    # Open NetCDF files
    file_dict = {}
    for ztype in ['land','plvl']:
        # Build path: RAW_DIR/era5_hires_land/era5_hires_land_2026-06-09_00UTC.nc
        subdir = RAW_DIR / f"{file_prefix}_{ztype}"
        fname = subdir / date_targ.strftime(
            file_prefix+"_"+ztype_dict[ztype]+"_%Y-%m-%d_%HUTC.nc"
        )
        file_dict[ztype+' fhandle'] = ncopen( str(fname), 'r' )
    # --- End of loop over data types


    # Generate density and altitude data from plvl data
    # -------------------------------------------------
    # Extract thermodynamic info from plvl data
    pres_in_Pa = np.squeeze( file_dict['plvl fhandle'].variables['pressure_level'] ) * 100
    spechum_in_kgkg = np.squeeze( file_dict['plvl fhandle'].variables['q'] )
    temp_in_K = np.squeeze( file_dict['plvl fhandle'].variables['t'] )

    # Compute density using array broadcasting rules. Assume pressure index is the third from the right.
    spechum_in_kgkg = np.swapaxes( spechum_in_kgkg, -3, -1)
    temp_in_K = np.swapaxes( temp_in_K, -3, -1)
    density_in_kgm3_on_plvls = compute_density( temp_in_K, pres_in_Pa, spechum_in_kgkg )
    density_in_kgm3_on_plvls = np.swapaxes( density_in_kgm3_on_plvls, -3, -1 )

    # Geopotential heights on plvls
    altitude_in_m_on_plvls = np.squeeze( file_dict['plvl fhandle'].variables['z'] ) / 9.80665

    # Coordinate informaiton
    lat1d = np.squeeze( file_dict['plvl fhandle'].variables['latitude'] )
    lon1d = np.squeeze( file_dict['plvl fhandle'].variables['longitude'] )


    # Generate density and altitude data from land data
    # -------------------------------------------------
    # Compute density on land
    psfc_in_Pa = np.squeeze( file_dict['land fhandle'].variables['sp'] )
    dwpt2m_in_K = np.squeeze( file_dict['land fhandle'].variables['d2m'])
    temp2m_in_K = np.squeeze( file_dict['land fhandle'].variables['t2m'])
    spechum2m_in_kgkg = dewpt_to_spechum( dwpt2m_in_K, psfc_in_Pa )
    density_in_kgm3_on_land = compute_density( temp2m_in_K, psfc_in_Pa, spechum2m_in_kgkg )

    # Geopotential heights on land
    altitude_in_m_on_land = np.squeeze( file_dict['land fhandle'].variables['z'] ) / 9.80665


    # Combining surface and plvl data
    # -------------------------------
    # Init arrays to hold combined data
    shp = np.array( density_in_kgm3_on_plvls.shape )
    shp[-3] += 1
    combined_density_in_kgm3 = np.zeros(shp, dtype='f8') +np.nan
    combined_altitude_in_m = np.zeros(shp, dtype='f8')   +np.nan        

    # Combine deterministic data
    if len(shp) == 3:
        combined_density_in_kgm3[1:] = density_in_kgm3_on_plvls
        combined_density_in_kgm3[0]  = density_in_kgm3_on_land
        combined_altitude_in_m[1:] = altitude_in_m_on_plvls
        combined_altitude_in_m[0]  = altitude_in_m_on_land
    # Combine ensemble data
    elif len(shp) == 4:
        combined_density_in_kgm3[:,1:] = density_in_kgm3_on_plvls
        combined_density_in_kgm3[:,0]  = density_in_kgm3_on_land
        combined_altitude_in_m[:,1:] = altitude_in_m_on_plvls
        combined_altitude_in_m[:,0]  = altitude_in_m_on_land

    # Sorting data to account for subterranean pressure levels
    sort_inds = np.argsort( combined_altitude_in_m, axis=-3 )
    combined_density_in_kgm3 = np.take_along_axis( combined_density_in_kgm3, sort_inds, axis=-3)
    combined_altitude_in_m   = np.take_along_axis( combined_altitude_in_m, sort_inds, axis=-3)


    # Identifying ground-level and above-ground points as valid
    # ---------------------------------------------------------
    # Dealing with deterministic data
    if len(shp) == 3:
        flags_valid = (combined_altitude_in_m >= altitude_in_m_on_land)
    elif len(shp) == 4:
        tmp = np.swapaxes( combined_altitude_in_m, 0, 1 )
        flags_valid = (tmp >= altitude_in_m_on_land)
        flags_valid = np.swapaxes( flags_valid, 0, 1 )


    # Release file handles
    # --------------------
    for ztype in ['land','plvl']:
        file_dict[ztype+' fhandle'].close()

    
    # Generate dictionary of data to return
    # -------------------------------------
    out_dict = {}
    out_dict['lon'] = {'info':'Array of longitudes in degrees East', 'units': 'degrees', 'data': lon1d}
    out_dict['lat'] = {'info':'Array of latitudes in degrees North', 'units': 'degrees', 'data': lat1d}
    out_dict['terrain'] = {'info': 'altitude of ground surface above mean sea level', 'units':'meters', 'data': altitude_in_m_on_land}
    out_dict['altitude'] = {'info': 'altitude of density data above mean sea level', 'units':'meters', 'data': combined_altitude_in_m}
    out_dict['air_density'] = {'info': 'Air density due to gaseous components', 'units':'kg/m3', 'data': combined_density_in_kgm3 }
    out_dict['valid_points'] = {'info': 'True if at ground level or above ground. False if underground.', 
                                'units':'none', 'data': flags_valid}

    return out_dict
# --- End of function to compute density based on era5 data
    



'''
    Main program
'''
for pfx in era5_prefix_list:
    for date_nw in date_list:

        print( 'Processing prefix ', pfx, ' on ', date_nw )

        # Compute density information
        density_data_dict = compute_density_from_era5_file( pfx, era5_ztype_dict, date_nw )

        # Output data as pickle file
        # Create subdirectory if needed
        out_subdir = DENSITY_DIR / pfx
        out_subdir.mkdir(parents=True, exist_ok=True)
        
        outfname = out_subdir / date_nw.strftime(
            'density_' + pfx + "_%Y-%m-%d_%HUTC.pkl"
        )
        with open( outfname, 'wb') as f:
            pickle.dump( density_data_dict, f )
        # --- end of pickle dump process
    # --- End of loop over ERA5 prefixes
# --- End of loop over dates




'''
    SANITY CHECK: Load and plot most recent pkl file
'''

with open( outfname, 'rb' ) as f:
    density_data_dict = pickle.load(f)


import matplotlib.pyplot as plt

fig, axs = plt.subplots( nrows=3, ncols=2, figsize=(6,8) )
axs = axs.flatten()

axs[0].set_title('altitude of layer 0')
cnf = axs[0].contourf( density_data_dict['lon']['data'], density_data_dict['lat']['data'], density_data_dict['altitude']['data'][0]  , 11, cmap='jet' )
plt.colorbar( cnf, ax = axs[0] )

axs[1].set_title('valid altitude at layer 0')
valid_altitude = density_data_dict['altitude']['data'][0] *1
valid_altitude[ np.invert( density_data_dict['valid_points']['data'][0]) ] = np.nan
cnf = axs[1].contourf( density_data_dict['lon']['data'], density_data_dict['lat']['data'], valid_altitude , 11, cmap='jet' )
plt.colorbar( cnf, ax = axs[1] )

for i0 in range(2):
    i = i0*2+2

    # Plot altitude
    ax = axs[i]
    ax.set_title('valid altitudes at layer %d' % i0)
    valid_altitude = density_data_dict['altitude']['data'][i0] *1
    valid_altitude[ np.invert( density_data_dict['valid_points']['data'][i0]) ] = np.nan
    cnf = ax.contourf( density_data_dict['lon']['data'], density_data_dict['lat']['data'], valid_altitude , 11, cmap='jet' )
    plt.colorbar( cnf, ax = ax )

    # Plot density
    ax = axs[i+1]
    ax.set_title( 'valid densities in layer %d' % i0)
    valid_density = density_data_dict['air_density']['data'][i0]*1
    valid_density[ np.invert( density_data_dict['valid_points']['data'][i0])  ] = np.nan
    cnf = ax.contourf( 
        density_data_dict['lon']['data'], density_data_dict['lat']['data'], valid_density, 
        np.linspace(1.15,1.25,6),  cmap='inferno', extend='both' )
    plt.colorbar( cnf, ax = ax )

plt.tight_layout()
plt.savefig('demo_air_density.png')