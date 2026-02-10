#!/bin/bash

# tz_2022_nbs_magu_district_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: tz_2022_nbs_districts
# Destination postGIS table: tz_2022_nbs_magu_district
#
# Created by etl() on 2026-02-10 13:37:47
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# create directory structure and move into it
mkdir -p /data/tz_2022_nbs_magu_district/{download,etl} && cd /data/tz_2022_nbs_magu_district

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

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


