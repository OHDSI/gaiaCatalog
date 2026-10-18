#!/bin/bash

# mdc_5000_addresses_normalized_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: file:///data/mdc_5000_addresses_normalized/download/mdc_5000_addresses_normalized
# Destination postGIS table: mdc_5000_addresses_normalized
#
# Created by etl() on 2026-10-17 21:39:10
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_5000_addresses_normalized/download -p /data/mdc_5000_addresses_normalized/etl
chmod -R 777 /data/mdc_5000_addresses_normalized
cd /data/mdc_5000_addresses_normalized

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then

  # check need for update based on update frequency
  update_frequency='As Needed'
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
  # remove spaces, periods, and leading numerical digits in column headers (if needed)
  if (head -n 1 download/mdc_5000_addresses_normalized.csv | grep -qE '\s|\.|\"[0-9]'); then
    sed -i '1s/ /_/g; 1s/\.//g; 1s/\"\([0-9]\)/\"n\1/g' download/mdc_5000_addresses_normalized.csv 2>&1
  fi
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/mdc_5000_addresses_normalized.csv -oo X_POSSIBLE_NAMES=x_coord -oo Y_POSSIBLE_NAMES=y_coord -s_srs EPSG:2236 -t_srs EPSG:4326 -nlt point -nln mdc_5000_addresses_normalized
echo success: mdc_5000_addresses_normalized.csv loaded with ogr2ogr


