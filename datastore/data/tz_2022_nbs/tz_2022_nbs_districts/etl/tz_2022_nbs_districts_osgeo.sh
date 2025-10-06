#!/bin/bash

# tz_2022_nbs_districts_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://microdata.nbs.go.tz/index.php/catalog/49/download/317
# Destination postGIS table: tz_2022_nbs_districts
#
# Created by etl() on 2025-10-05 15:59:41
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# create directory structure and move into it
mkdir -p /data/tz_2022_nbs/{download,tz_2022_nbs_districts/etl} && cd /data/tz_2022_nbs

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
      wget -O download/tz_2022_nbs.zip 'https://microdata.nbs.go.tz/index.php/catalog/49/download/317'
  done
  unzip -d download download/tz_2022_nbs.zip && rm download/tz_2022_nbs.zip
  7z x download/TANZANIA_2022_POST_PHC_GEODATABASE.mpkx -o'download/TANZANIA_2022_POST_PHC_GEODATABASE'
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
(exit 1)
until [[ "$?" == 0 ]]; do
  ogr2ogr -lco GEOMETRY_NAME=geom -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/TANZANIA_2022_POST_PHC_GEODATABASE/commondata/tanzania_2022phc_geodatabase.gdb Districts -nlt multipolygon -nln tz_2022_nbs_districts
done

