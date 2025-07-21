#!/bin/bash

# ma_2018_svi_tract_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip
# Destination postGIS table: ma_2018_svi_tract
#
# Created by etl() on 2025-06-30 18:24:58
# Do not edit directly

# Create derivative directory in data package on osgeo
cd /data/ma_2018_svi_tract/
mkdir -p derived


