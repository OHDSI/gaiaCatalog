#!/bin/bash

# us_2019_tract_tl_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://www2.census.gov/geo/tiger/TIGER2019/TRACT/tl_2019_<state fips>_tract.zip
# Destination postGIS table: us_2019_tract_tl

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)

# states to load (two-digit FIPS codes, space separated); the default is Alabama.
# Set TRACT_STATES in the gaia-db container environment to load others, e.g. "01 04 06 41".
STATES="${TRACT_STATES:-01}"

# create directory structure and move into it
mkdir -p /data/us_2019_tract_tl/download -p /data/us_2019_tract_tl/etl
chmod -R 777 /data/us_2019_tract_tl
cd /data/us_2019_tract_tl

# check for existence
export TZ=EST5EDT
do_update=0
list=$(ls)
file=datestamp
exists=$(test "${list#*$file}" != "$list" && echo 1)
if [[ $exists ]]; then
  # these datasets never change: skip the download when a datestamp exists
  do_update=0
else do_update=1; fi

# download if needed
if [[ $do_update = 1 ]]; then
  for st in $STATES; do
    attempts=0
    until (
      wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/tl_2019_${st}_tract.zip "https://www2.census.gov/geo/tiger/TIGER2019/TRACT/tl_2019_${st}_tract.zip" 2>&1
    ); do
      ((attempts++))
      if (( attempts > 3 )); then echo $?; break; fi
    done
    unzip -o download/tl_2019_${st}_tract.zip -d download && rm download/tl_2019_${st}_tract.zip 2>&1
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS (one shapefile per state, appended to one table)
first=1
for st in $STATES; do
  if [[ $first = 1 ]]; then
    ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tl_2019_${st}_tract.shp -nlt multipolygon -nln us_2019_tract_tl
    first=0
  else
    ogr2ogr -append -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tl_2019_${st}_tract.shp -nlt multipolygon -nln us_2019_tract_tl
  fi
  echo success: tl_2019_${st}_tract.shp loaded with ogr2ogr
done
