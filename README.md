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


## Setup / Instructions 

1. Set up [CDS Api](https://cds.climate.copernicus.eu/how-to-api)
2. Activate virtual environment 
```
source isp_venv/bin/activate
```
or
```
load_conda
conda activate isp
```
Note: `load_conda` is defined in `~/.bashrc` as `alias load_conda='eval "$(/users/PAS2635/otho7246/miniconda3/bin/conda shell.bash hook)"'`
3. Install/check packages: (note, the last three packages must be installed with pip, not conda)
```
pip install numpy matplotlib geopy scipy pandas netcdf4 mceq "cdsapi>=0.7.7"
```
4. Set up config file accordingly (in `config/`)
5. Run scripts: (leaving `<path_to_config>` blank defaults to `config/default.sh`)
```
./submit_prep_density_data.sh <path_to_config>
./submit_spline_jobs.sh <path_to_config>
./submit_muflux_jobs.sh <path_to_config>
./combine_muflux_files.sh <path_to_config>
./extract_psfc_muflux.sh <path_to_config>
```
7. Use `plot_output.ipynb` to visualize summary


## About the Output Density Data
Density data, along with longitude, latitude, and altitude data, are output in the 
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
    
    
## Plotting Data

plot_output.ipynb shows an example of how to plot the resultant muon fluxes as a function of time. You will need to replace the filepaths to point to your own data files containing the files resulting from combine_muflux_files.sh

extract_psfc.py contains an example of how to extract a particular true atmospheric quantity from the *.pkl files that are generated when downloading the era5 data. This is useful if you (for example) want to compare the muon fluxes with the true atmospheric pressure at a given location/time. Note however, that in order to run this script, you will need to replace the filepaths with ones pointing to your .pkl files, wherever those live. 
