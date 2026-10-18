#!/bin/bash

# synthetic_county_ses_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/data/county_ses.csv
# Destination postGIS table: synthetic_county_ses

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)

# create directory structure and move into it
mkdir -p /data/synthetic_county_ses/download -p /data/synthetic_county_ses/etl
chmod -R 777 /data/synthetic_county_ses
cd /data/synthetic_county_ses

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
  # fail after 3 attempts
  attempts=0
  until (
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_county_ses.csv 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/data/county_ses.csv' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS (a plain table; values stay text so no digits are lost, and the county polygons are joined in the postgis step)
ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/synthetic_county_ses.csv -dialect sqlite -sql "SELECT geoid, ses_index FROM synthetic_county_ses" -lco COLUMN_TYPES="geoid=varchar,ses_index=varchar" -nlt NONE -nln synthetic_county_ses
echo success: synthetic_county_ses.csv loaded with ogr2ogr

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi
