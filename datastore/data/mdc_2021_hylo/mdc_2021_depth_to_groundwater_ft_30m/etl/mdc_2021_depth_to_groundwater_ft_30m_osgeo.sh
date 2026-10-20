#!/bin/bash

# mdc_2021_depth_to_groundwater_ft_30m_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13395678880002976&download=true
# Destination postGIS table: mdc_2021_depth_to_groundwater_ft_30m
#
# Created by etl() on 2026-10-20 10:45:19
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_2021_hylo/download -p /data/mdc_2021_hylo/mdc_2021_depth_to_groundwater_ft_30m/etl
chmod -R 777 /data/mdc_2021_hylo
cd /data/mdc_2021_hylo

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
    if [[ "$check_date" -ge "$last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

# download if needed
if [[ $do_update = 1 ]]; then
  # fail after 3 attempts
  attempts=0
  until (
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/mdc_2021_hylo.zip 'https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13395678880002976&download=true' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  unzip -o download/mdc_2021_hylo.zip -d download && rm download/mdc_2021_hylo.zip 2>&1
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS

