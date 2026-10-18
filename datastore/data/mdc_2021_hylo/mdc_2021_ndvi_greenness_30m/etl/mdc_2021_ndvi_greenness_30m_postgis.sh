#!/bin/bash

# mdc_2021_ndvi_greenness_30m_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13395678880002976&download=true
# Destination postGIS table: mdc_2021_ndvi_greenness_30m
#
# Created by etl() on 2026-10-09 22:52:11
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
    cd /data/mdc_2021_hylo/download
    raster2pgsql -s 3857 -d -C -I -t 48x48 GeoTIFF_Rasters/Greenness_30m_MDC.tif -F mdc_2021_ndvi_greenness_30m > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    echo success: GeoTIFF_Rasters/Greenness_30m_MDC.tif loaded with raster2pgsql
    rm load_raster.sql
    cd /data/mdc_2021_hylo
); do
  ((attempts++))
  if (( attempts > 3 )); then echo $?; break; fi
done

