#!/bin/bash
# Script for processing model data, including annual and seasonal mean calculations.

# ==============================================================================
# Copyright (C) 2025 Centre for Climate Change Research (CCCR), IITM
#
# This script is part of the CCCR IITM_ESM diagnostics system.
#
# Author: [Pritam Das Mahapatra]
# Date: March 2025
# ==============================================================================

if [ "$#" -lt 6 ]; then
    echo "Usage: $0 <variable1 variable2 ...> <season> <netcdf_dir> <start_year> <end_year> <output_prefix>"
    exit 1
fi

variables=("${@:1:$#-5}")
season="${@: -5:1}"
netcdf_dir="${@: -4:1}"
start_year_model="${@: -3:1}"
end_year_model="${@: -2:1}"
output_prefix="${@: -1:1}"

echo "Processing variables: ${variables[@]}"
echo "Season: $season"
echo "NetCDF directory: $netcdf_dir"
echo "Start year: $start_year_model"
echo "End year: $end_year_model"
echo "Output prefix: $output_prefix"

function check_error {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Define output directory from the wrapper
output_dir="./output_data"
mkdir -p "$output_dir"

function get_season_months {
    case "$1" in
        DJF) echo "12,1,2" ;;
        MAM) echo "3,4,5" ;;
        JJA) echo "6,7,8" ;;
        SON) echo "9,10,11" ;;
        JJAS) echo "6,7,8,9" ;;
        *) echo "Error: Invalid season $1"; exit 1 ;;
    esac
}

# Iterate over each variable and process
for var in "${variables[@]}"; do
    echo "Starting processing for variable: $var"

    # Define output files with prefix
    model_annual_mean_file="${output_dir}/${output_prefix}_annual_mean_${var}.nc"
    model_season_mean_file="${output_dir}/${output_prefix}_${season}_mean_${var}.nc"

    # Skip processing if final output files already exist
    if [ -f "$model_annual_mean_file" ] && [ -f "$model_season_mean_file" ]; then
        echo "Annual and seasonal mean files for $var already exist. Skipping calculations."
        continue
    fi

    season_months=$(get_season_months "$season")
    monthly_temp_files=()

    for year in $(seq "$start_year_model" "$end_year_model"); do
        for month in $(seq -w 01 12); do
            monthly_file=$(ls "$netcdf_dir"/*"${year}_${month}"*.nc 2> /dev/null | head -n 1)
            if [ -z "$monthly_file" ]; then
                echo "No file found for $year-$month. Skipping."
                continue
            fi

            if ! ncdump -h "$monthly_file" | grep -q " $var("; then
                echo "Variable $var not found in $monthly_file. Skipping."
                continue
            fi

            temp_var_file="temp_${output_prefix}_${var}_${year}_${month}.nc"
            cdo selvar,"$var" "$monthly_file" "$temp_var_file"
            check_error "Selecting variable $var for $year-$month"
            monthly_temp_files+=("$temp_var_file")
        done
    done

    if [ ${#monthly_temp_files[@]} -gt 0 ]; then
        yearly_merged_file="merged_${output_prefix}_${var}.nc"
        cdo mergetime "${monthly_temp_files[@]}" "$yearly_merged_file"
        check_error "Merging monthly files for $var"

        # Calculate overall annual mean
        cdo timmean "$yearly_merged_file" "$model_annual_mean_file"
        check_error "Calculating overall annual mean for $var"

        # Calculate seasonal mean
        seasonal_merged_file="selected_${output_prefix}_${season}_${var}.nc"
        cdo selmon,$season_months "$yearly_merged_file" "$seasonal_merged_file"
        check_error "Selecting $season months for $var"
        cdo timmean "$seasonal_merged_file" "$model_season_mean_file"
        check_error "Calculating ${season} mean for $var"

        # Cleanup
        rm "$yearly_merged_file" "$seasonal_merged_file" "${monthly_temp_files[@]}"
    fi

    echo "Completed processing for variable: $var"
done

echo "All variables processed successfully."

