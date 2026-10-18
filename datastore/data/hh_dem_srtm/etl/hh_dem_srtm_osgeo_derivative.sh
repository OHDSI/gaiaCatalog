#!/bin/bash

# hh_dem_srtm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://step.esa.int/auxdata/dem/SRTMGL1/
# Destination postGIS table: hh_dem_srtm
#
# Created by etl() on 2026-10-17 21:44:25
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_dem_srtm/
mkdir -p derived

# Create downloadable zip of download/geotiff in derivate directory 
rm -f derived/hh_dem_srtm.tif.tar.gz
tar -czf derived/hh_dem_srtm.tif.tar.gz meta_dcat_hh_dem_srtm.json -C download hh_dem_srtm.tif


