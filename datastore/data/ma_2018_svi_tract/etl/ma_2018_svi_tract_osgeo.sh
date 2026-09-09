#!/bin/bash

# ma_2018_svi_tract_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip
# Destination postGIS table: ma_2018_svi_tract
#
# Created by etl() on 2026-09-08 22:16:32
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)

# create directory structure and move into it
mkdir -p /data/ma_2018_svi_tract/download -p /data/ma_2018_svi_tract/etl
chmod -R 777 /data/ma_2018_svi_tract
cd /data/ma_2018_svi_tract

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
    if [[ "$check_date -ge $last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

# download if needed
if [[ $do_update = 1 ]]; then
  # fail after 3 attempts to download
  attempts=0
  until (
    wget -O download/ma_2018_svi_tract.zip 'https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip'
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  unzip -o download/ma_2018_svi_tract.zip -d download && rm download/ma_2018_svi_tract.zip
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/SVI2018_MASSACHUSETTS_tract.gdb -nlt multipolygon -nln ma_2018_svi_tract


