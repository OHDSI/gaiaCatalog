#!/bin/bash

# tz_magu_dem_srtm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://step.esa.int/auxdata/dem/SRTMGL1/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2026-09-11 21:43:14
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# fail after 3 attempts to download
attempts=0
until (
    cd /data/tz_magu_dem_srtm/download
    raster2pgsql -s 4326 -d -C -I -t auto tz_magu_dem_srtm.tif -F tz_magu_dem_srtm > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    echo success: tz_magu_dem_srtm.tif loaded with raster2pgsql
    rm load_raster.sql
    cd /data/tz_magu_dem_srtm
); do
  ((attempts++))
  if (( attempts > 3 )); then echo $?; break; fi
done

