#!/bin/bash

# us_2014_2019_monthly_pm25_by_tract_cdc_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://data.cdc.gov/resource/qjxm-7fny.csv (2014-2015) and https://data.cdc.gov/resource/96sd-hxdt.csv (2016-2019)
# Destination postGIS table: us_2014_2019_monthly_pm25_by_tract_cdc

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)

# states to load (two-digit FIPS codes, space separated); the default is Alabama.
# Set TRACT_STATES in the gaia-db container environment to load others, e.g. "01 04 06 41".
STATES="${TRACT_STATES:-01}"
# the 2016-2020 dataset stores state codes without the leading zero, the 2011-2015 dataset with it
IN_LIST=""
for st in $STATES; do IN_LIST="$IN_LIST,'$st','$((10#$st))'"; done
IN_LIST="${IN_LIST#,}"

# create directory structure and move into it
mkdir -p /data/us_2014_2019_monthly_pm25_by_tract_cdc/download -p /data/us_2014_2019_monthly_pm25_by_tract_cdc/etl
chmod -R 777 /data/us_2014_2019_monthly_pm25_by_tract_cdc
cd /data/us_2014_2019_monthly_pm25_by_tract_cdc

# download if there is no datestamp (the source years are fixed)
do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  TOKEN=""
  [[ -n "$CDC_APP_TOKEN" ]] && TOKEN="--data-urlencode \$\$app_token=$CDC_APP_TOKEN"
  fetch() {  # fetch <dataset id> <years> <output file>
    local query="SELECT year, substring(date,3,3) AS mon, statefips, countyfips, ctfips, avg(ds_pm_pred) AS pm25_mean_pred WHERE statefips in ($IN_LIST) AND year in ($2) GROUP BY year, mon, statefips, countyfips, ctfips LIMIT 5000000"
    attempts=0
    until curl -sf -G "https://data.cdc.gov/resource/$1.csv" --data-urlencode "\$query=$query" $TOKEN --retry 3 --max-time 1800 -o "$3"; do
      ((attempts++))
      if (( attempts > 3 )); then echo "download of $1 failed"; break; fi
    done
  }
  # server-side monthly aggregation: the daily data are about 26 million rows per year
  fetch qjxm-7fny "'2014','2015'" download/part1.csv
  fetch 96sd-hxdt "'2016','2017','2018','2019'" download/part2.csv
  (cat download/part1.csv; tail -n +2 download/part2.csv) > download/us_2014_2019_monthly_pm25_by_tract_cdc.csv
  rm -f download/part1.csv download/part2.csv
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS: one jsonb series per tract (tract codes zero-padded to eleven digits)
ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/us_2014_2019_monthly_pm25_by_tract_cdc.csv -dialect sqlite -sql "WITH all_rows AS (SELECT DATE(year || '-' || CASE mon WHEN 'JAN' THEN '01' WHEN 'FEB' THEN '02' WHEN 'MAR' THEN '03' WHEN 'APR' THEN '04' WHEN 'MAY' THEN '05' WHEN 'JUN' THEN '06' WHEN 'JUL' THEN '07' WHEN 'AUG' THEN '08' WHEN 'SEP' THEN '09' WHEN 'OCT' THEN '10' WHEN 'NOV' THEN '11' WHEN 'DEC' THEN '12' END || '-01') AS start_date, FORMAT('%011d', CAST(ctfips AS INTEGER)) AS geoid, CAST(pm25_mean_pred AS decimal) AS pm25_mean_pred FROM us_2014_2019_monthly_pm25_by_tract_cdc WHERE pm25_mean_pred != '') SELECT SUBSTR(geoid, 1, 2) AS statefips, SUBSTR(geoid, 3, 3) AS countyfips, geoid, JSON_GROUP_OBJECT(start_date || '/' || DATE(start_date, '+1 month', '-1 day'), pm25_mean_pred) AS pm25_mean_pred FROM all_rows GROUP BY geoid" -lco COLUMN_TYPES="pm25_mean_pred=jsonb" -nlt NONE -nln us_2014_2019_monthly_pm25_by_tract_cdc
echo success: us_2014_2019_monthly_pm25_by_tract_cdc.csv loaded with ogr2ogr
