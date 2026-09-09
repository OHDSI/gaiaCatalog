#!/bin/bash

# tz_1984_copernicus_avg_temp_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2026-09-09 15:19:51
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
    cd /data/tz_1984_copernicus_avg_temp/download
    raster2pgsql -s 4326 -d -C -I -t auto tz_1984_copernicus_avg_temp.tif -F tz_1984_copernicus_avg_temp > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    rm load_raster.sql
    cd /data/tz_1984_copernicus_avg_temp
); do
  ((attempts++))
  if (( attempts > 3 )); then echo $?; break; fi
done

