# ==============================================================================
#  Copyright (C) 2025 Centre for Climate Change Research (CCCR), IITM
#
#  This script is part of the CCCR IITM_ESM diagnostics system.
#
#  Author: Pritam Das Mahapatra
#  Date: March 2025
#  Version: 1.2 (Seasonal SSS Bias Plot)
#
# ==============================================================================

import sys
import os
import numpy as np
import xarray as xr
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from cartopy.mpl.ticker import LongitudeFormatter, LatitudeFormatter
import matplotlib
matplotlib.use('Agg')  # For non-interactive backend

# === Read input arguments ===
model1_season = sys.argv[1]
model2_season_regridded = sys.argv[2]
obs_season_regridded = sys.argv[3]
var = sys.argv[4]  # SSS variable name in models
obs_var = sys.argv[5]  # SSS variable name in observations
output_dir = sys.argv[6]
projection = sys.argv[7]
lat_range = sys.argv[8]
lon_range = sys.argv[9]
season = sys.argv[10]  # Added seasonal argument

# Debugging Information
print("=== INPUT ARGUMENTS ===")
print(f"Model 1 Seasonal Mean: {model1_season}")
print(f"Model 2 Seasonal Mean: {model2_season_regridded}")
print(f"Observation Seasonal: {obs_season_regridded}")
print(f"Projection: {projection}")
print(f"Latitude Range: {lat_range}")
print(f"Longitude Range: {lon_range}")
print(f"Variable: {var} and Obs Variable: {obs_var}")
print(f"Season: {season}")
print("========================")

# Parse latitude and longitude ranges
try:
    lat_min, lat_max = map(float, lat_range.strip().split(","))
    lon_min, lon_max = map(float, lon_range.strip().split(","))
except ValueError:
    print("Error: Latitude or Longitude range is not properly defined. Expected format: 'min,max'.")
    sys.exit(1)

# === Load datasets ===
try:
    model1_ds = xr.open_dataset(model1_season, decode_times=False)
    model2_ds = xr.open_dataset(model2_season_regridded, decode_times=False) if model2_season_regridded else None
    obs_ds = xr.open_dataset(obs_season_regridded, decode_times=False)

    # Extract SSS variable and select first time step
    model1_season_data = model1_ds[var].isel(time=0) if "time" in model1_ds.dims else model1_ds[var]
    model2_season_data = model2_ds[var].isel(time=0) if model2_season_regridded and "time" in model2_ds.dims else model2_ds[var] if model2_season_regridded else None

    # Select first depth level if available
    if "depth" in obs_ds.dims:
        obs_season_data = obs_ds[obs_var].isel(time=0, depth=0) if "time" in obs_ds.dims else obs_ds[obs_var].isel(depth=0)
    else:
        obs_season_data = obs_ds[obs_var].isel(time=0) if "time" in obs_ds.dims else obs_ds[obs_var]

except Exception as e:
    print(f"Error loading datasets: {e}")
    sys.exit(1)

# === Compute Biases ===
bias1_season_data = model1_season_data - obs_season_data  # Bias (Model 1 - Obs)
bias2_season_data = model2_season_data - obs_season_data if model2_season_regridded else None  # Bias (Model 2 - Obs)
bias3_season_data = model1_season_data - model2_season_data if model2_season_regridded else None  # Bias (Model 1 - Model 2)

# Dynamically identify coordinates
if "xt_ocean" in model1_season_data.coords and "yt_ocean" in model1_season_data.coords:
    lon_name, lat_name = "xt_ocean", "yt_ocean"
elif "lon" in model1_season_data.coords and "lat" in model1_season_data.coords:
    lon_name, lat_name = "lon", "lat"
else:
    raise ValueError("Longitude and latitude coordinates not found in dataset.")

# Define levels
mean_levels = np.arange(34, 38, 0.25)  # SSS typically ranges from -2°C (polar) to ~35°C (tropics)
bias_levels = np.arange(-2, 2, 0.25)  # Bias range
# Colormaps
mean_cmap = 'Spectral_r'  # For model and observation
bias_cmap = 'coolwarm'  # For bias

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

# Function to plot SSS data
def plot_map(ax, data, title, levels, cmap):
    """Generic function for plotting data with Cartopy."""
    contour = ax.contourf(
        data.coords[lon_name], data.coords[lat_name], data,  
        transform=ccrs.PlateCarree(), levels=levels, cmap=cmap, extend="both"
    )
    ax.coastlines()
    ax.set_extent([lon_min, lon_max, lat_min, lat_max], crs=ccrs.PlateCarree(central_longitude=180))
    ax.set_xticks(np.linspace(lon_min, lon_max, 5), crs=ccrs.PlateCarree())
    ax.set_yticks(np.linspace(lat_min, lat_max, 5), crs=ccrs.PlateCarree())
    ax.xaxis.set_major_formatter(LongitudeFormatter())
    ax.yaxis.set_major_formatter(LatitudeFormatter())
    ax.tick_params(labelsize=10)
    ax.set_title(title)
    return contour

# Create a 3x2 grid for plotting
fig, axes = plt.subplots(3, 2, figsize=(15, 18), subplot_kw={"projection": ccrs.PlateCarree()})

# Plot Observation Seasonal Mean
contour1 = plot_map(axes[0, 0], obs_season_data, f"Observation SSS {season} Mean", mean_levels, mean_cmap)
fig.colorbar(contour1, ax=axes[0, 0], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)

# Plot Bias between Model 1 and Model 2 (if Model 2 exists)
if bias3_season_data is not None:
    contour2 = plot_map(axes[0, 1], bias3_season_data, f"Bias (CMIP7 - CMIP6) {season}", bias_levels, bias_cmap)
    fig.colorbar(contour2, ax=axes[0, 1], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)

# Plot Model 1 Seasonal Mean
contour3 = plot_map(axes[1, 0], model1_season_data, f"CMIP7 SSS {season} Mean", mean_levels, mean_cmap)
fig.colorbar(contour3, ax=axes[1, 0], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)

# Plot Model 2 Seasonal Mean (if exists)
if model2_season_data is not None:
    contour4 = plot_map(axes[2, 0], model2_season_data, f"CMIP6 SSS {season} Mean", mean_levels, mean_cmap)
    fig.colorbar(contour4, ax=axes[2, 0], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)

# Plot Bias between Model 1 and Observation
contour5 = plot_map(axes[1, 1], bias1_season_data, f"Bias (CMIP7 - Obs) {season}", bias_levels, bias_cmap)
fig.colorbar(contour5, ax=axes[1, 1], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)

# Plot Bias between Model 2 and Observation (if Model 2 exists)
if bias2_season_data is not None:
    contour6 = plot_map(axes[2, 1], bias2_season_data, "Bias (CMIP6 - Obs) {season}", bias_levels, bias_cmap)
    fig.colorbar(contour6, ax=axes[2, 1], orientation='horizontal', pad=0.1, fraction=0.05, shrink=0.8)
    
# Save the plot
output_file = os.path.join(output_dir, f"{var}_seasonal_comparison_sss_{season}_{projection}.png")
plt.savefig(output_file)
print(f"Plot saved to {output_file}")
plt.close()

