#!/bin/bash
# ==============================================================================
# Copyright (C) 2025 Centre for Climate Change Research (CCCR), IITM
#
# This script is part of the CCCR IITM_ESM diagnostics system.
#
# Author: Pritam Das Mahapatra
# Date: March 2025
# ==============================================================================

# Function for error handling
function check_error {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Enable debug mode if requested
debug=false
if [ "$1" == "-d" ]; then
    debug=true
    shift
fi

# Parse input arguments from main wrapper
variables=("${@:1:$#-7}")  
season="${@: -7:1}"
projection="${@: -6:1}"
lat_range="${@: -5:1}"
lon_range="${@: -4:1}"
model1_prefix="${@: -3:1}"
model2_prefix="${@: -2:1}"
obs_prefix="${@: -1:1}"

# Debug: Print parsed arguments
if $debug; then
    echo "Debug: Check inputs for plotting function:"
    echo "  Variables: ${variables[@]}"
    echo "  Season: $season"
    echo "  Projection: $projection"
    echo "  Latitude Range: $lat_range"
    echo "  Longitude Range: $lon_range"
    echo "  Model 1 Prefix: $model1_prefix"
    echo "  Model 2 Prefix: $model2_prefix"
    echo "  Observation Prefix: $obs_prefix"
fi

# Ensure all required inputs are set
if [[ -z "$season" || -z "$projection" || -z "$lat_range" || -z "$lon_range" || -z "$model1_prefix" || -z "$model2_prefix" || -z "$obs_prefix" ]]; then
    echo "Error: Missing required arguments. Check input variables."
    exit 1
fi

# Define output directory
output_dir="./output_data"
mkdir -p "$output_dir"

# Log skipped variables
skipped_log="$output_dir/skipped_plot_variables.log"
> "$skipped_log"

# Function to verify file existence
function verify_file {
    if [ ! -f "$1" ]; then
        echo "Error: File $1 not found. Skipping..."
        echo "$1: Missing file" >> "$skipped_log"
        return 1
    fi
}

declare -A variable_mapping=(
    ["sss"]="s_mn"  
    ["sst"]="t_mn"  
)

# Function to regrid data (including Model 2)
function regrid_data {
    local var="$1"
    local obs_var="${variable_mapping[$var]}"  

    if [[ -z "$obs_var" ]]; then
        echo "Error: No mapping found for variable $var. Skipping..."
        echo "$var: No mapping found" >> "$skipped_log"
        return 1
    fi

    if $debug; then
        echo "Debug: Regridding data for $var (Obs Variable: $obs_var)..."
    fi

    # Define file paths
    local obs_annual="$output_dir/${obs_var}_annual_mean.nc"
    local obs_season="$output_dir/${obs_var}_seasonal_mean_${season}.nc"
    local obs_annual_regridded="${output_dir}/obs_annual_mean_${obs_var}_regridded.nc"
    local obs_season_regridded="${output_dir}/obs_${season}_mean_${obs_var}_regridded.nc"

    local model1_annual="${model1_prefix}_annual_mean_${var}.nc"
    local model1_season="${model1_prefix}_${season}_mean_${var}.nc"
    local model2_annual="${model2_prefix}_annual_mean_${var}.nc"
    local model2_season="${model2_prefix}_${season}_mean_${var}.nc"

    local model1_grid="${model1_prefix}_grid.txt"
    if [ ! -f "$model1_grid" ]; then
        echo "Extracting grid for Model 1..."
        cdo griddes "$model1_annual" > "$model1_grid"
        check_error "Extracting grid for Model 1"
    fi

    # Regrid observation data
    if [ ! -f "$obs_annual_regridded" ]; then
        verify_file "$obs_annual" || return
        cdo remapbil,"$model1_grid" "$obs_annual" "$obs_annual_regridded"
        check_error "Regridding annual observation data for $var"
    fi
    if [ ! -f "$obs_season_regridded" ]; then
        verify_file "$obs_season" || return
        cdo remapbil,"$model1_grid" "$obs_season" "$obs_season_regridded"
        check_error "Regridding seasonal observation data for $var"
    fi

    # **Regrid Model 2 Data**
    local model2_annual_regridded="${output_dir}/model2_annual_mean_${var}_regridded.nc"
    local model2_season_regridded="${output_dir}/model2_${season}_mean_${var}_regridded.nc"

    if [ ! -f "$model2_annual_regridded" ]; then
        verify_file "$model2_annual" || return
        cdo remapbil,"$model1_grid" "$model2_annual" "$model2_annual_regridded"
        check_error "Regridding annual Model 2 data for $var"
    fi

    if [ ! -f "$model2_season_regridded" ]; then
        verify_file "$model2_season" || return
        cdo remapbil,"$model1_grid" "$model2_season" "$model2_season_regridded"
        check_error "Regridding seasonal Model 2 data for $var"
    fi
}

# Function to call Python plot scripts directly
function call_specialized_plot {
    local var="$1"
    local obs_var="${variable_mapping[$var]}"  

    if [[ -z "$obs_var" ]]; then
        echo "Error: No mapping found for variable $var. Skipping..."
        echo "$var: No mapping found" >> "$skipped_log"
        return 1
    fi

    if $debug; then
        echo "Debug: Calling Python plotting script for $var (Obs Variable: $obs_var)..."
    fi

    local obs_annual_regridded="${output_dir}/obs_annual_mean_${obs_var}_regridded.nc"
    local obs_season_regridded="${output_dir}/obs_${season}_mean_${obs_var}_regridded.nc"
    local model1_annual="${model1_prefix}_annual_mean_${var}.nc"
    local model1_season="${model1_prefix}_${season}_mean_${var}.nc"
    local model2_annual_regridded="${output_dir}/model2_annual_mean_${var}_regridded.nc"
    local model2_season_regridded="${output_dir}/model2_${season}_mean_${var}_regridded.nc"

    # Call Python plot scripts
    echo "Generating plots for $var (Annual)..."
    python3 "${var}_plotting_script_ann.py" "$model1_annual" "$model2_annual_regridded" \
        "$obs_annual_regridded" "$var" "$obs_var" "$output_dir" "$projection" "$lat_range" "$lon_range"
    check_error "Generating plots for $var Annual"

    echo "Generating plots for $var (Seasonal)..."
    python3 "${var}_plotting_script_season.py" "$model1_season" "$model2_season_regridded" \
        "$obs_season_regridded" "$var" "$obs_var" "$output_dir" "$projection" "$lat_range" "$lon_range" "$season"
    check_error "Generating plots for $var Seasonal"
}

# Process each variable
for var in "${variables[@]}"; do
    regrid_data "$var"
    call_specialized_plot "$var"
done

echo "Plotting completed successfully. Outputs saved in $output_dir."

