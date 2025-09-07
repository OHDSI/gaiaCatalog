#!/bin/bash

# tz_magu_dem_srtm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2025-09-07 17:36:05
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_magu_dem_srtm/
mkdir -p derived


