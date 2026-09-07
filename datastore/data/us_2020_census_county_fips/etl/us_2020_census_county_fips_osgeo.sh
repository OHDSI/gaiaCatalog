#!/bin/bash

# us_2020_census_county_fips_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://api.census.gov/data/2020/dec/dp?get=NAME&for=county:*
# Destination postGIS table: us_2020_census_county_fips
#
# Created by etl() on 2026-09-06 12:36:54
# Do not edit directly

# create directory structure and move into it
mkdir -p /data/us_2020_census_county_fips/download -p /data/us_2020_census_county_fips/etl
chmod -R 777 /data/us_2020_census_county_fips
cd /data/us_2020_census_county_fips

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

# Download and etl as needed
if [[ $do_update = 1 ]]; then
  curl -o download/us_2020_census_county_fips.json "https://api.census.gov/data/2020/dec/dp?get=NAME&for=county:*&key=f2d1ef72bd4b793b33f640ac711d90c3454fc559"
fi
awk '{gsub(/\[|\]|.$/,""); print;}' download/us_2020_census_county_fips.json | sed 's/, /\",\"/g' | sed 's/\"NAME\"/\"county_name\",\"state_name\"/g' | ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" csv:/vsistdin/ -nln us_2020_census_county_fips

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


