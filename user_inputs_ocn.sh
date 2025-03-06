#!/bin/bash
# User inputs for IITM_ESM diagnostic wrapper script
# Last updated: March 2025

# Diagnostic settings
diagnostic_type="climate_analysis"  # Example: "climate_analysis" or "model_comparison"
component_type="OCN"                # Component type: "ATM" (Atmosphere), "OCN" (Ocean), "ICE" (Ice)


# Output directory for all generated files
plot_dir="/home/iitm/IITM_ESM_WRAPPER/Final_wrapper/OCN/PLOT"  # Specify where output files should be saved
# Variables to process (comma-separated list)
variables="sst,sss"  # Unified list of variables

# Model 1 data settings
netcdf_dir_model1="/media/iitm/TOSHIBA_PRITAM/CMIP6/OCN"  # Directory containing Model 1 data files
start_year_model1=1990              # Start year for Model 1 data
end_year_model1=1995               # End year for Model 1 data
output_prefix_model1="model1"       # Output file prefix for Model 1

# Model 2 data settings (Mandatory for comparison)
netcdf_dir_model2="/home/cccr/shamal/CMIP6/OCN"  # Directory containing Model 2 data files
start_year_model2=1990              # Start year for Model 2 data
end_year_model2=2014                # End year for Model 2 data
output_prefix_model2="model2"       # Output file prefix for Model 2

# Observation data settings
obs_data_dir="/home/cccr/pritam/OBS_wrapper/WOA23"  # Directory containing observational data files
start_year_obs=1991                   # Start year for observational data
end_year_obs=2020                      # End year for observational data

# Seasonal settings
season="JJAS"                          # Season to analyze (e.g., "DJF", "MAM", "JJA", "SON", "JJAS")

# Plot settings based on component type
case "$component_type" in
    "ATM")
        projection="Robinson"          # Projection type for atmospheric data
        lat_range="-90,90"             # Latitude range for global analysis
        lon_range="0,360"              # Longitude range for global analysis
        ;;
    "OCN")
        projection="platecarree"          # Projection for ocean data
        lat_range="-90,90"             # Focused latitude range for ocean data
        lon_range="-180,180"            # Focused longitude range for ocean data
        ;;
    "ICE")
        projection="polar"             # Polar projection for ice data
        lat_range="60,90"              # High-latitude range for ice analysis
        lon_range="0,360"              # Full longitude range
        ;;
    *)
        echo "Error: Invalid component type. Must be 'ATM', 'OCN', or 'ICE'."
        exit 1
        ;;
esac

# Debugging mode (optional)
debug=false  # Set to true for verbose output

if [ "$debug" = true ]; then
    set -x  # Enable verbose output
fi

