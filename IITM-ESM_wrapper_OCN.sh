#!/bin/bash
# DESCRIPTION: Wrapper script for IITM_ESM diagnostics with model comparison
# Last updated: March 2025

######################################### USER INPUT SECTION ##########################################

# Check if the user input file exists
if [[ ! -f "user_inputs_ocn.sh" ]]; then
    echo "Error: 'user_inputs_ocn.sh' file not found. Please create this file with required inputs."
    exit 1
fi

# Source user inputs from the external file
source ./user_inputs_ocn.sh

# Error handling and cleanup
function check_error {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

function cleanup {
    echo "Cleaning up temporary files..."
    rm -f temp_model1_*.nc temp_model2_*.nc temp_obs_*.nc model_grid_*.nc temp_*_*_data.nc 2>/dev/null || true
}
trap cleanup EXIT

# Ensure necessary arguments are provided
required_vars=(
    diagnostic_type variables netcdf_dir_model1 start_year_model1 end_year_model1
    netcdf_dir_model2 start_year_model2 end_year_model2
    season projection lat_range lon_range obs_data_dir start_year_obs end_year_obs
)

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Required variable '$var' is missing in 'user_inputs_ocn.sh'."
        exit 1
    fi
done

# Convert variable list to an array
IFS=',' read -r -a variables_array <<< "$variables"

# Enable debug mode if requested
if [ "$debug" = true ]; then
    set -x
fi

# Display parsed variables
echo "Selected diagnostic type: $diagnostic_type"
echo "Variables: ${variables_array[@]}"
echo "Season: $season"
echo "Projection: $projection"
echo "Latitude range: $lat_range"
echo "Longitude range: $lon_range"
echo "Using model 1 data directory: $netcdf_dir_model1"
echo "Using model 2 data directory: $netcdf_dir_model2"

# Define output directory
output_dir="./output_data"
mkdir -p "$output_dir"
echo "Output files will be saved in $output_dir"

######################################### MODEL PROCESSING ##########################################

# Function to run model data processing
function process_model {
    local model_num=$1
    local model_dir=$2
    local start_year=$3
    local end_year=$4
    local output_prefix=$5
    
    echo "Starting processing for Model $model_num..."
    ./process_model_data.sh "${variables_array[@]}" "$season" "$model_dir" "$start_year" "$end_year" "$output_prefix"
    check_error "Model $model_num processing failed."
    echo "Model $model_num processing completed."
}

# Process Model 1 with its prefix
process_model "1" "$netcdf_dir_model1" "$start_year_model1" "$end_year_model1" "$output_prefix_model1"

# Process Model 2 with its prefix
process_model "2" "$netcdf_dir_model2" "$start_year_model2" "$end_year_model2" "$output_prefix_model2"

######################################### OBSERVATION PROCESSING ##########################################

echo "Starting observation data processing..."
./observation_data_processing_ocn.sh "${variables_array[@]}" "$obs_data_dir" "$start_year_obs" "$end_year_obs" "$season"
check_error "Observation data processing failed."
echo "Observation data processing completed."

######################################### PLOTTING ##########################################

echo "Starting plotting functions..."

# Validate required variables
if [ -z "$season" ] || [ -z "$projection" ] || [ -z "$lat_range" ] || [ -z "$lon_range" ]; then
    echo "Error: One or more required variables (season, projection, lat_range, lon_range) are not set."
    exit 1
fi

if [ ${#variables_array[@]} -eq 0 ]; then
    echo "Error: Variables array is empty. Nothing to process."
    exit 1
fi

if [ -z "$output_dir" ] || [ -z "$output_prefix_model1" ] || [ -z "$output_prefix_model2" ]; then
    echo "Error: Output directory or model prefixes are not set."
    exit 1
fi

# Debug mode handling
debug_flag=""
if $debug; then
    debug_flag="-d"
    echo "Debug: Starting plotting with the following inputs:"
    echo "  Variables: ${variables_array[@]}"
    echo "  Season: $season"
    echo "  Projection: $projection"
    echo "  Latitude Range: $lat_range"
    echo "  Longitude Range: $lon_range"
    echo "  Output Directory: $output_dir"
    echo "  Model 1 Prefix: $output_prefix_model1"
    echo "  Model 2 Prefix: $output_prefix_model2"
    echo "  Observation Prefix: final_obs_"
fi

# Verify plotting script existence
if [ ! -f "./plotting_functions.sh" ]; then
    echo "Error: Plotting script 'plotting_functions.sh' not found."
    exit 1
fi

# Run the plotting script
./plotting_functions.sh $debug_flag \
    "${variables_array[@]}" \
    "$season" "$projection" "$lat_range" "$lon_range" \
    "$output_dir/${output_prefix_model1}" "$output_dir/${output_prefix_model2}" "$output_dir/final_obs_"


if [ $? -ne 0 ]; then
    echo "Error: Plotting script failed to execute successfully."
    exit 1
fi

echo "Plotting completed successfully."
echo "Processing and plotting completed successfully. Outputs are saved in $output_dir."

# Load user inputs

source ./user_inputs_ocn.sh

echo "COPYING ALL PLOTS INTO PLOT DIRECTORY: $plot_dir"

# Ensure the plot directory exists
mkdir -p "$plot_dir"

# Find and copy all .png and .pdf plots into $plot_dir
find . -type f \( -iname "*.png" -o -iname "*.pdf" \) -exec cp {} "$plot_dir/" \;

echo "All plots successfully copied to $plot_dir."
######################## FINAL OUTPUT MANAGEMENT##############
######################################## CLEANUP ##########################################

echo "Choose cleanup option:"
echo "1) Delete Model 1 processed files"
echo "2) Delete Model 2 and Observational processed files"
echo "3) Delete All processed files"
echo "4) Skip Cleanup"
read -r user_input

case "$user_input" in
    1)
        echo "Deleting Model 1 processed files..."
        find "$output_dir" -type f -name "${output_prefix_model1}_*.nc" -exec rm -f {} +
        find . -maxdepth 1 -type f -name "${output_prefix_model1}_*.nc" -exec rm -f {} +
        echo "Model 1 files deleted."
        ;;
    2)
        echo "Deleting Model 2 and Observational processed files..."
        find "$output_dir" -type f \( -name "${output_prefix_model2}_*.nc" -o -name "obs_*.nc" -o -name "final_obs_*.nc" \) -exec rm -f {} +
        find . -maxdepth 1 -type f \( -name "${output_prefix_model2}_*.nc" -o -name "obs_*.nc" -o -name "final_obs_*.nc" \) -exec rm -f {} +
        echo "Model 2 and Observational files deleted."
        ;;
    3)
        echo "Deleting all processed files..."
        find "$output_dir" -type f -name "*.nc" -exec rm -f {} +
        find . -maxdepth 1 -type f -name "*.nc" -exec rm -f {} +
        echo "All processed files deleted."
        ;;
    4)
        echo "Cleanup skipped. Processed files are retained in $output_dir."
        ;;
    *)
        echo "Invalid choice. Cleanup aborted."
        ;;
esac

######################################### CREATE HTML ##########################################

echo "Generating HTML file with plot previews..."

# Define the image details file
img_list_file="${plot_dir}/image_list.txt"
output_html="${plot_dir}/plots_overview.html"

# Generate the list of plots with captions
echo "Generating image list..."
rm -f "$img_list_file"  # Remove existing file if present

# Add each plot to the image list
for img in "$plot_dir"/*.png; do
    echo "$img" >> "$img_list_file"  # Image file path
    echo "$(basename "$img")" >> "$img_list_file"  # Use file name as caption
done

# Check if any images were added
if [[ ! -s "$img_list_file" ]]; then
    echo "No images found for HTML generation."
else
    # Run the Python script to generate the HTML
    python create_plot_html.py "$img_list_file" "$output_html"
    if [[ $? -eq 0 ]]; then
        echo "HTML file created successfully: $output_html"
    else
        echo "Error: Failed to generate HTML file."
    fi
fi

######################################## FINAL OUTPUT MANAGEMENT ##########################################

echo "Processing, plotting, and HTML generation completed successfully."

echo "Script execution completed."
