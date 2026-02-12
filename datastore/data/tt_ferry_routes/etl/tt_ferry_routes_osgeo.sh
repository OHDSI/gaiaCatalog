#!/bin/bash

# tt_ferry_routes_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=way%5B%22route%22~%22ferry%22%5D(area:3600555717);(._;>;);out;
# Destination postGIS table: tt_ferry_routes
#
# Created by etl() on 2026-02-12 11:05:28
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# create directory structure and move into it
mkdir -p /data/tt_ferry_routes/{download,etl} && cd /data/tt_ferry_routes

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
  (exit 1)
  until [[ "$?" == 0 ]]; do
      curl -o download/tt_ferry_routes.osm 'https://overpass-api.de/api/interpreter?data=way%5B%22route%22~%22ferry%22%5D(area:3600555717);(._;>;);out;'
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
(exit 1)
until [[ "$?" == 0 ]]; do
  ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tt_ferry_routes.osm
done

