#!/bin/bash

# us_2015_2019_monthly_pm25_by_county_cdc_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://data.cdc.gov/api/v3/views/53mz-4zqd/query.csv?query=SELECT%0A%20%20%60year%60%2C%0A%20%20%60date%60%2C%0A%20%20%60statefips%60%2C%0A%20%20%60countyfips%60%2C%0A%20%20%60pm25_max_pred%60%2C%0A%20%20%60pm25_med_pred%60%2C%0A%20%20%60pm25_mean_pred%60%2C%0A%20%20%60pm25_pop_pred%60%0AWHERE%0A%20%20caseless_one_of(%60year%60%2C%20%222014%22%2C%20%222015%22%2C%20%222016%22%2C%20%222017%22%2C%20%222018%22%2C%20%222019%22)&app_token='"$CDC_APP_TOKEN"'
# Destination postGIS table: us_2015_2019_monthly_pm25_by_county_cdc
#
# Created by etl() on 2026-09-08 22:17:05
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)

# create directory structure and move into it
mkdir -p /data/us_2015_2019_monthly_pm25_by_county_cdc/download -p /data/us_2015_2019_monthly_pm25_by_county_cdc/etl
chmod -R 777 /data/us_2015_2019_monthly_pm25_by_county_cdc
cd /data/us_2015_2019_monthly_pm25_by_county_cdc

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
    wget -O download/us_2015_2019_monthly_pm25_by_county_cdc.csv 'https://data.cdc.gov/api/v3/views/53mz-4zqd/query.csv?query=SELECT%0A%20%20%60year%60%2C%0A%20%20%60date%60%2C%0A%20%20%60statefips%60%2C%0A%20%20%60countyfips%60%2C%0A%20%20%60pm25_max_pred%60%2C%0A%20%20%60pm25_med_pred%60%2C%0A%20%20%60pm25_mean_pred%60%2C%0A%20%20%60pm25_pop_pred%60%0AWHERE%0A%20%20caseless_one_of(%60year%60%2C%20%222014%22%2C%20%222015%22%2C%20%222016%22%2C%20%222017%22%2C%20%222018%22%2C%20%222019%22)&app_token='"$CDC_APP_TOKEN"''
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  # remove spaces and periods for all column headers and make sure no column starts with a number
  sed -i '1 s/ /_/g; s/\.//g;  s/\"\([0-9]\)/\"n\1/g' download/us_2015_2019_monthly_pm25_by_county_cdc.csv
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/us_2015_2019_monthly_pm25_by_county_cdc.csv -dialect sqlite -sql "WITH all_rows AS (SELECT year, DATE(SUBSTR(date, 6) || '-' || CASE SUBSTR(date, 3, 3) WHEN 'JAN' THEN '01' WHEN 'FEB' THEN '02' WHEN 'MAR' THEN '03' WHEN 'APR' THEN '04' WHEN 'MAY' THEN '05' WHEN 'JUN' THEN '06' WHEN 'JUL' THEN '07' WHEN 'AUG' THEN '08' WHEN 'SEP' THEN '09' WHEN 'OCT' THEN '10' WHEN 'NOV' THEN '11' WHEN 'DEC' THEN '12' END || '-01') AS start_date, FORMAT('%02d', statefips) AS statefips, FORMAT('%03d', countyfips) AS countyfips, MAX(CAST(pm25_max_pred AS decimal)) AS pm25_max_pred, MEDIAN(CAST(pm25_med_pred AS decimal)) AS pm25_med_pred, AVG(CAST(pm25_mean_pred AS decimal)) AS pm25_mean_pred, AVG(CAST(pm25_pop_pred AS decimal)) AS pm25_pop_pred FROM us_2015_2019_monthly_pm25_by_county_cdc WHERE pm25_max_pred != '' AND pm25_med_pred != '' AND pm25_mean_pred != '' AND pm25_pop_pred != '' GROUP BY statefips, countyfips, start_date) SELECT statefips, countyfips, statefips || countyfips as geoid, JSON_GROUP_OBJECT(start_date || '/' || DATE(start_date, '+1 month', '-1 day'), pm25_max_pred) AS pm25_max_pred, JSON_GROUP_OBJECT(start_date || '/' || DATE(start_date, '+1 month', '-1 day'), pm25_med_pred) AS pm25_med_pred, JSON_GROUP_OBJECT(start_date || '/' || DATE(start_date, '+1 month', '-1 day'), pm25_mean_pred) AS pm25_mean_pred, JSON_GROUP_OBJECT(start_date || '/' || DATE(start_date, '+1 month', '-1 day'), pm25_pop_pred) AS pm25_pop_pred FROM all_rows GROUP BY statefips, countyfips" -lco COLUMN_TYPES="pm25_mean_pred=jsonb,pm25_med_pred=jsonb,pm25_max_pred=jsonb,pm25_pop_pred=jsonb" -nlt multipolygon -nln us_2015_2019_monthly_pm25_by_county_cdc

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


