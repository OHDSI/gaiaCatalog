#!/bin/bash

# fl_2025_tl_tract_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: ftp://ftp2.census.gov/geo/tiger/TIGER2025/TRACT/tl_2025_12_tract.zip
# Destination postGIS table: fl_2025_tl_tract
#
# Created by etl() on 2026-10-18 11:41:47
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/fl_2025_tl_tract/download -p /data/fl_2025_tl_tract/etl
chmod -R 777 /data/fl_2025_tl_tract
cd /data/fl_2025_tl_tract

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
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/fl_2025_tl_tract.zip 'ftp://ftp2.census.gov/geo/tiger/TIGER2025/TRACT/tl_2025_12_tract.zip' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  unzip -o download/fl_2025_tl_tract.zip -d download && rm download/fl_2025_tl_tract.zip 2>&1
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tl_2025_12_tract.shp -nlt multipolygon -nln fl_2025_tl_tract
echo success: tl_2025_12_tract.shp loaded with ogr2ogr


