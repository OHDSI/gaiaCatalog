#!/bin/bash

# hh_lagunas_ana_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://geosnirh.ana.gob.pe/server/rest/services/P%C3%BAblico/Lagunas/MapServer/36/query?where=1%3D1&geometry=%22xmin%22%3A-77.33%2C%22ymin%22%3A-10.7%2C%22xmax%22%3A-76.55%2C%22ymax%22%3A-9.8&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=4326&f=geojson
# Destination postGIS table: hh_lagunas_ana
#
# Created by etl() on 2026-10-17 21:42:50
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/hh_lagunas_ana/download -p /data/hh_lagunas_ana/etl
chmod -R 777 /data/hh_lagunas_ana
cd /data/hh_lagunas_ana

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then

  # check need for update based on update frequency
  update_frequency='Never'
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
  ogr2ogr -nln hh_lagunas_ana download/hh_lagunas_ana.json 'https://geosnirh.ana.gob.pe/server/rest/services/P%C3%BAblico/Lagunas/MapServer/36/query?where=1%3D1&geometry=%22xmin%22%3A-77.33%2C%22ymin%22%3A-10.7%2C%22xmax%22%3A-76.55%2C%22ymax%22%3A-9.8&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=4326&f=geojson 2>&1'
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/hh_lagunas_ana.json -nlt multipolygon -nln hh_lagunas_ana
echo success: hh_lagunas_ana.json loaded with ogr2ogr


