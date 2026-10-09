#!/bin/bash

# us_2019_prisecroads_tl_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://www2.census.gov/geo/tiger/TIGER2019/PRISECROADS/tl_2019_<state fips>_prisecroads.zip
# Destination postGIS table: us_2019_prisecroads_tl

export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)

STATES="${TRACT_STATES:-01}"

mkdir -p /data/us_2019_prisecroads_tl/download -p /data/us_2019_prisecroads_tl/etl
chmod -R 777 /data/us_2019_prisecroads_tl
cd /data/us_2019_prisecroads_tl

do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  for st in $STATES; do
    attempts=0
    until (
      wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/tl_2019_${st}_prisecroads.zip "https://www2.census.gov/geo/tiger/TIGER2019/PRISECROADS/tl_2019_${st}_prisecroads.zip" 2>&1
    ); do
      ((attempts++))
      if (( attempts > 3 )); then echo $?; break; fi
    done
    unzip -o download/tl_2019_${st}_prisecroads.zip -d download && rm download/tl_2019_${st}_prisecroads.zip 2>&1
  done
  echo $(date '+%F %T') > datestamp
fi

first=1
for st in $STATES; do
  if [[ $first = 1 ]]; then
    ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tl_2019_${st}_prisecroads.shp -nlt multilinestring -nln us_2019_prisecroads_tl
    first=0
  else
    ogr2ogr -append -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tl_2019_${st}_prisecroads.shp -nlt multilinestring -nln us_2019_prisecroads_tl
  fi
  echo success: tl_2019_${st}_prisecroads.shp loaded with ogr2ogr
done
