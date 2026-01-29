#!/bin/bash

# ma_2020_svi_tract_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2020/db/states/Massachusetts.zip
# Destination postGIS table: ma_2020_svi_tract
#
# Created by etl() on 2026-01-29 11:52:29
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/ma_2020_svi_tract/
mkdir -p derived

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

