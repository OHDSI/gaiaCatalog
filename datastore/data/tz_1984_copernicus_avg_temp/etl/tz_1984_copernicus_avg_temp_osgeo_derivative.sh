#!/bin/bash

# tz_1984_copernicus_avg_temp_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2026-09-08 22:16:45
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_1984_copernicus_avg_temp/
mkdir -p derived

# Create downloadable zip of download/geotiff in derivate directory 
rm -f derived/tz_1984_copernicus_avg_temp.tif.tar.gz
tar -czf derived/tz_1984_copernicus_avg_temp.tif.tar.gz meta_dcat_tz_1984_copernicus_avg_temp.json -C download tz_1984_copernicus_avg_temp.tif


