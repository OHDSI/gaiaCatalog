#!/bin/bash

# tz_magu_dem_srtm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://step.esa.int/auxdata/dem/SRTMGL1/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2026-09-09 21:11:36
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_magu_dem_srtm/
mkdir -p derived

# Create downloadable zip of download/geotiff in derivate directory 
rm -f derived/tz_magu_dem_srtm.tif.tar.gz
tar -czf derived/tz_magu_dem_srtm.tif.tar.gz meta_dcat_tz_magu_dem_srtm.json -C download tz_magu_dem_srtm.tif


