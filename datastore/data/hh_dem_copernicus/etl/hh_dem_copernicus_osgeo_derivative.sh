#!/bin/bash

# hh_dem_copernicus_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: hh_dem_copernicus
#
# Created by etl() on 2026-10-17 21:45:06
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_dem_copernicus/
mkdir -p derived

# Create downloadable zip of download/geotiff in derivate directory 
rm -f derived/hh_dem_copernicus.tif.tar.gz
tar -czf derived/hh_dem_copernicus.tif.tar.gz meta_dcat_hh_dem_copernicus.json -C download hh_dem_copernicus.tif


