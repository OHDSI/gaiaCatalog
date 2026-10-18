#!/bin/bash

# mdc_2014_viirs_vnp46a4_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://ladsweb.modaps.eosdis.nasa.gov/api/v2/content/archives/VNP46A4.A2014001.h09v06.002.2025091141033.h5
# Destination postGIS table: mdc_2014_viirs_vnp46a4
#
# Created by etl() on 2026-10-17 21:53:50
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# fail after 3 attempts
attempts=0
until (
    cd /data/mdc_2014_viirs_vnp46a4/download
    raster2pgsql -s 4326 -d -C -I -t auto VNP46A4.A2014001.h09v06.002.2025091141033.tif -F mdc_2014_viirs_vnp46a4 > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    echo success: VNP46A4.A2014001.h09v06.002.2025091141033.tif loaded with raster2pgsql
    rm load_raster.sql
    cd /data/mdc_2014_viirs_vnp46a4
); do
  ((attempts++))
  if (( attempts > 3 )); then echo $?; break; fi
done

