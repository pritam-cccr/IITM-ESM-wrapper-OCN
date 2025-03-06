#!/bin/bash
# ==============================================================================
# DESCRIPTION: Script for processing observation climatology for SSS and SST
# using yearly mean files to generate annual and seasonal climatology.
# ==============================================================================
# Copyright (C) 2025 Centre for Climate Change Research (CCCR), IITM
#
# Author: Pritam Das Mahapatra
# Date: March 2025
# ==============================================================================

# Error handling function
function check_error {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Initialize variables
variables=()
obs_data_dir=""
start_year_obs=""
end_year_obs=""
season=""

# Parse arguments
for arg in "$@"; do
    if [[ -z "$obs_data_dir" && "$arg" =~ ^[a-zA-Z] ]]; then
        variables+=("$arg")
    elif [ -z "$obs_data_dir" ]; then
        obs_data_dir="$arg"
    elif [ -z "$start_year_obs" ]; then
        start_year_obs="$arg"
    elif [ -z "$end_year_obs" ]; then
        end_year_obs="$arg"
    elif [ -z "$season" ]; then
        season="$arg"
    fi
done

# Debugging and validation output
echo "Parsed variables: ${variables[@]}"
echo "Observation data directory: $obs_data_dir"
echo "Start year: $start_year_obs"
echo "End year: $end_year_obs"
echo "Season: $season"

# Validation
if [ -z "$obs_data_dir" ] || [ -z "$start_year_obs" ] || [ -z "$end_year_obs" ] || [ -z "$season" ]; then
    echo "Error: Missing required observation data processing parameters."
    exit 1
fi

# Output directory
output_dir="./output_data"
mkdir -p "$output_dir"
log_file="$output_dir/error_log.txt"
echo "Output files will be saved in $output_dir"
echo "Error log will be saved in $log_file"

# Variable mapping for observations
declare -A variable_mapping=(
    ["sss"]="s_mn"  # SSS maps to s_mn in observations
    ["sst"]="t_mn"  # SST maps to t_mn in observations
)

# Seasonal definitions (month numbers)
declare -A seasons=(
    ["DJF"]="12 01 02"  # December, January, February
    ["MAM"]="03 04 05"  # March, April, May
    ["JJA"]="06 07 08"  # June, July, August
    ["SON"]="09 10 11"  # September, October, November
    ["JJAS"]="06 07 08 09"  # June, July, August, September
)

# Process each variable
for var in "${variables[@]}"; do
    obs_var="${variable_mapping[$var]}"  # Use mapped observation variable name

    echo "Processing climatology for observation variable: $obs_var"

    # Paths to precomputed climatology files
    annual_mean_file="${obs_data_dir}/${obs_var}_woa23_annual_mean.nc"
    yearly_mean_files=()
    for month in {01..12}; do
        yearly_mean_files+=("${obs_data_dir}/${obs_var}_woa23_yearly_mean_${month}.nc")
    done

    # Check if the annual mean file exists
    if [ -f "$output_dir/${obs_var}_annual_mean.nc" ]; then
        echo "Skipping $obs_var: Annual mean already exists."
    else
        if [ ! -f "$annual_mean_file" ]; then
            echo "Error: Annual mean file for $obs_var is missing: $annual_mean_file" | tee -a "$log_file"
            continue
        fi
        cp "$annual_mean_file" "$output_dir/${obs_var}_annual_mean.nc"
        check_error "Copying annual mean file for $obs_var"
    fi

    # Generate seasonal climatology
    seasonal_climatology_file="$output_dir/${obs_var}_seasonal_mean_${season}.nc"

    # Skip processing if the seasonal file already exists
    if [ -f "$seasonal_climatology_file" ]; then
        echo "Skipping $obs_var: Seasonal climatology for $season already exists."
        continue
    fi

    echo "Generating seasonal climatology for $obs_var..."
    season_months="${seasons[$season]}"

    # Collect valid files for selected months
    valid_files=()
    for month in $season_months; do
        month_file="${obs_data_dir}/${obs_var}_woa23_yearly_mean_${month}.nc"
        if [ -f "$month_file" ]; then
            valid_files+=("$month_file")
        else
            echo "Warning: Missing yearly mean file for month $month -> $month_file"
        fi
    done

    # Check if we have valid files before running CDO
    if [ ${#valid_files[@]} -eq 0 ]; then
        echo "Error: No valid input files for seasonal climatology. Skipping $obs_var."
        continue
    fi

    # Compute seasonal mean from yearly mean files of selected months
    cdo ensmean "${valid_files[@]}" "$seasonal_climatology_file"
    check_error "Generating $season climatology for $obs_var"

    echo "Seasonal climatology for $obs_var has been generated and saved in $output_dir."
done

echo "Processing completed for observation climatology. Check $log_file for any errors."

