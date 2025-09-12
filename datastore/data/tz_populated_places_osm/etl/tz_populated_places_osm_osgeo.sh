#!/bin/bash

# tz_populated_places_osm_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=area%28id:3600195270%29-%3E.searchArea;node%5B%22place%22~%22city|town|village|hamlet%22%5D%28area.searchArea%29;%28._;%3E;%29;out;
# Destination postGIS table: tz_populated_places_osm
#
# Created by etl() on 2025-09-11 18:03:33
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# create directory structure and move into it
mkdir -p /data/tz_populated_places_osm/{download,etl} && cd /data/tz_populated_places_osm

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
      curl -o download/tz_populated_places_osm.osm 'https://overpass-api.de/api/interpreter?data=area%28id:3600195270%29-%3E.searchArea;node%5B%22place%22~%22city|town|village|hamlet%22%5D%28area.searchArea%29;%28._;%3E;%29;out;'
  done
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
(exit 1)
until [[ "$?" == 0 ]]; do
  ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/tz_populated_places_osm.osm
done

