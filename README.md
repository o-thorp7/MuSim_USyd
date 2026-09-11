# System to obtain muon fluxes from ERA5
> Initially written by Man-Yau (Joseph) Chan, extended by William Luszczak

## Description
This system is composed of 2 parts: a set of programs to pull and process ERA5 data to extrat the density field, and a set of scripts to run muom flux simulations using the extracted atmospheric information. 

### Programs to obtain ERA5 data:
This system of programs generate density data from ERA5.
There are two sets of programs: download programs and the density calculation program.

Download programs download the necessary data from the ERA5 Climate Data Store.
Both the ERA5 lower-resolution 10-member ensemble and the ERA5 higher-resolution 1-member 
ensemble (i.e., the control member) are downloaded. 

The density calculation program converts the downloaded ERA5 data into density data.

### Scripts to run muon flux simulation
These scripts will used the unpacked and processed ERA5 data to generate a simulated muon flux measurement.
This entails splining the density field, averaging it azimuth, and then running a "representative" muon flux calculation through the resultant x-z density profile. 
The muon flux as a function of zenith is then integrated to arrive at an estimated total muon flux rate per square meter (Hz/m^2) 


## System Requirements
*Python version 3.10+
*Python packages numpy, matplotlib, netCDF4, cdsapi, sys, datetime, pickle
*CDS API, see setup instructions here: https://cds.climate.copernicus.eu/how-to-api
*MCEq: https://github.com/mceq-project/MCEq
*Scripts are written to work with Slurm, though can probably be adapted to use a different job submission framework. 


## Usage Instructions
The procedure to use the ERA5 system is:

1)  Define the settings relevant to your situation in `config.sh`.
   The settings to control this program are in `config.sh`. 
   See comments within `config.sh` for an explanation of what those settings mean.


2)  Run the system using the script `run_download_and_process.sh`. I recommend submitting
    a SLURM job to run the code because the downloading process takes quite a while. 
    For example,
    ```
        sbatch -n 4 -N 1 -t 01:00:00 -o log.prep_density_data -A $PROJECT_CODE  \
            run_download_and_process.sh
    ```

    <!-- changes made by oli -->
    Or if running locally on Linux, try
    ```
    nohup bash run_download_and_process.sh > log.prep_density_data 2>&1 &
    ```

    <!--  -->

Once ERA5 files have been downloaded and processed, the muon flux calculation can be done via:

1) Define relevant settings in (lon, lat, account number, output directory) submit_spline_jobs.sh

2) mkdir splines mufluxes

2) ./submit_spline_jobs.sh

3) ./submit_muflux_jobs.sh

4) ./combine_muflux_files.sh

You should then end up with a bunch of .npy files in the mufluxes/ directory, with names like `combined_muflux_${timestamp}.npy`. These files should contain muon fluxes as a function of cos(zenith angle), and the numbers within can be totaled up to arrive at a total muon flux for that time period. 

## About the Outputted Density Data
Density data, along with longitude, latitude, and altitude data, are outputted in the 
form of Python pickle files. 

Two such pickle files are produced for each date: 
1) One file for the control member (`density_era5_hires_*.pkl`)
2) One file for the 10-member ensemble (`density_era5_ensem_*.pkl`)

Both kinds of pickle file contain data in similar Python dictionary setups. Here's the 
code snippet defining those dictionaries
```python
    out_dict['lon'] = {
        'info':'1D array of longitudes in degrees East', 
        'units': 'degrees', 
        'data': lon1d
    }
    out_dict['lat'] = {
        'info':'1D array of latitudes in degrees North', 
        'units': 'degrees', 
        'data': lat1d
    }
    out_dict['terrain'] = {
        'info': 'altitude of ground surface above mean sea level', 
        'units':'meters', 
        'data': altitude_in_m_on_land
    }
    out_dict['altitude'] = {
        'info': 'altitude of density data above mean sea level', 
        'units':'meters', 
        'data': combined_altitude_in_m
    }
    out_dict['air_density'] = {
        'info': 'Air density due to gaseous components', 
        'units':'kg/m3', 
        'data': combined_density_in_kgm3
    }
    out_dict['valid_points'] = {
        'info': 'True if at ground level or above ground. False if underground.', 
        'units':'none', 
        'data': flags_valid
    }
```


The data format in the `hires` file differs from that of the `ensem` file. To be precise, 
the `air_density`, `altitude`, and `valid_points` data arrays have one more dimension in the 
`ensem` file than in the `hires` file. 

Dimensions of `air_density`, `altitude`, and `valid_points` in `hires` files:
    level, latitude, longitude

Dimensions of `air_density`, `altitude`, and `valid_points` in `ensem` files:
    ensemble, level, latitude, longitude# MuSim_USyd
