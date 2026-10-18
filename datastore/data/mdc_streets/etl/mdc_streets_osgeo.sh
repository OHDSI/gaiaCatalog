#!/bin/bash

# mdc_streets_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/GeoStreets_gdb/FeatureServer/0/query?outFields=*&where=1%3D1&outSR=4326&f=geojson
# Destination postGIS table: mdc_streets
#
# Created by etl() on 2026-10-17 21:37:31
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_streets/download -p /data/mdc_streets/etl
chmod -R 777 /data/mdc_streets
cd /data/mdc_streets

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then

  # check need for update based on update frequency
  update_frequency='1 week'
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
  ogr2ogr -nln mdc_streets download/mdc_streets.geojson 'https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/GeoStreets_gdb/FeatureServer/0/query?outFields=*&where=1%3D1&outSR=4326&f=geojson 2>&1'
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/mdc_streets.geojson -nlt multilinestring -nln mdc_streets
echo success: mdc_streets.geojson loaded with ogr2ogr


