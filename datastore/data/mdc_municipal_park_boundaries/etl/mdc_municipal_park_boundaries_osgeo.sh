#!/bin/bash

# mdc_municipal_park_boundaries_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://opendata.arcgis.com/api/v3/datasets/16fe02a1defa45b28bf14a29fb5f0428_0/downloads/data?format=geojson&spatialRefId=4326&where=1%3D1
# Destination postGIS table: mdc_municipal_park_boundaries
#
# Created by etl() on 2026-10-09 22:52:53
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_municipal_park_boundaries/download -p /data/mdc_municipal_park_boundaries/etl
chmod -R 777 /data/mdc_municipal_park_boundaries
cd /data/mdc_municipal_park_boundaries

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then

  # check need for update based on update frequency
  update_frequency='6 months'
  no_update='-- As Needed Never'
  no_update=$(test "${no_update#*$update_frequency}" != "$no_update" && echo 1)
  if [[ ! $no_update ]]; then
    last_update=$(date -d "$(cat datestamp)" '+%s')
    check_date="$(date -d '-'"$update_frequency" '+%s')"
    if [[ "$check_date" -ge "$last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

# download if needed
if [[ $do_update = 1 ]]; then
  # fail after 3 attempts
  attempts=0
  until (
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/mdc_municipal_park_boundaries.geojson 'https://opendata.arcgis.com/api/v3/datasets/16fe02a1defa45b28bf14a29fb5f0428_0/downloads/data?format=geojson&spatialRefId=4326&where=1%3D1' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/mdc_municipal_park_boundaries.geojson -nlt multipolygon -nln mdc_municipal_park_boundaries
echo success: mdc_municipal_park_boundaries.geojson loaded with ogr2ogr


