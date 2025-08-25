#!/bin/bash

# us_2018_svi_county_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states_counties/SVI_2018_US_county.zip
# Destination postGIS table: us_2018_svi_county
#
# Created by etl() on 2025-08-24 13:21:35
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/us_2018_svi_county/
mkdir -p derived


