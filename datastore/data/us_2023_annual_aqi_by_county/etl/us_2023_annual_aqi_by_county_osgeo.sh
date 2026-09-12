#!/bin/bash

# us_2023_annual_aqi_by_county_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://aqs.epa.gov/aqsweb/airdata/annual_aqi_by_county_2023.zip
# Destination postGIS table: us_2023_annual_aqi_by_county
#
# Created by etl() on 2026-09-11 21:43:27
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/us_2023_annual_aqi_by_county/download -p /data/us_2023_annual_aqi_by_county/etl
chmod -R 777 /data/us_2023_annual_aqi_by_county
cd /data/us_2023_annual_aqi_by_county

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
    if [[ "$check_date -ge $last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

# download if needed
if [[ $do_update = 1 ]]; then
  # fail after 3 attempts to download
  attempts=0
  until (
    OPENSSL_CONF=/openssl/openssl.conf curl -o download/us_2023_annual_aqi_by_county.zip 'https://aqs.epa.gov/aqsweb/airdata/annual_aqi_by_county_2023.zip' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  unzip -o download/us_2023_annual_aqi_by_county.zip -d download && rm download/us_2023_annual_aqi_by_county.zip 2>&1
  # remove spaces, periods, and leading numerical digits in column headers (if needed)
  if (head -n 1 download/annual_aqi_by_county_2023.csv | grep -qE '\s|\.|\"[0-9]'); then
    sed -i '1s/ /_/g; 1s/\.//g; 1s/\"\([0-9]\)/\"n\1/g' download/annual_aqi_by_county_2023.csv 2>&1
  fi
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/annual_aqi_by_county_2023.csv -nlt multipolygon -nln us_2023_annual_aqi_by_county
echo success: annual_aqi_by_county_2023.csv loaded with ogr2ogr

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


