#!/bin/bash

# us_2018_svi_county_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states_counties/SVI_2018_US_county.zip
# Destination postGIS table: us_2018_svi_county
#
# Created by etl() on 2026-09-06 12:36:53
# Do not edit directly

# create directory structure and move into it
mkdir -p /data/us_2018_svi_county/download -p /data/us_2018_svi_county/etl
chmod -R 777 /data/us_2018_svi_county
cd /data/us_2018_svi_county

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
  attempts=0
  until (
    wget -O download/us_2018_svi_county.zip 'https://svi.cdc.gov/Documents/Data/2018/db/states_counties/SVI_2018_US_county.zip'
  ); do
    ((attempts++))
    if [[ attempts > 3 ]]; then echo $?; break; fi
  done
  unzip -d download download/us_2018_svi_county.zip && rm download/us_2018_svi_county.zip
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/SVI2018_US_county.gdb -nlt multipolygon -nln us_2018_svi_county


