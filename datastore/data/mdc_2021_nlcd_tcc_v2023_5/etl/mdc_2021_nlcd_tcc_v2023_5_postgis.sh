#!/bin/bash

# mdc_2021_nlcd_tcc_v2023_5_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://www.mrlc.gov/downloads/sciweb1/shared/mrlc/data-bundles/nlcd_tcc_CONUS_2021_v2021-4.zip
# Destination postGIS table: mdc_2021_nlcd_tcc_v2023_5
#
# Created by etl() on 2026-10-17 21:24:45
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
    cd /data/mdc_2021_nlcd_tcc_v2023_5/download
    raster2pgsql -s 4326 -d -C -I -t 48x48 mdc_2021_nlcd_tcc_v2023_5.tif -F mdc_2021_nlcd_tcc_v2023_5 > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    echo success: mdc_2021_nlcd_tcc_v2023_5.tif loaded with raster2pgsql
    rm load_raster.sql
    cd /data/mdc_2021_nlcd_tcc_v2023_5
); do
  ((attempts++))
  if (( attempts > 3 )); then echo $?; break; fi
done

