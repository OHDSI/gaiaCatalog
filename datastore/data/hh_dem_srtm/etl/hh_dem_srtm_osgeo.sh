#!/bin/bash

# hh_dem_srtm_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://step.esa.int/auxdata/dem/SRTMGL1/
# Destination postGIS table: hh_dem_srtm
#
# Created by etl() on 2026-10-17 21:44:25
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/hh_dem_srtm/download -p /data/hh_dem_srtm/etl
chmod -R 777 /data/hh_dem_srtm
cd /data/hh_dem_srtm

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
    if [[ "$check_date" -ge "$last_update" ]]; then do_update=1; fi
  fi

# does not exist
else do_update=1; fi

if [[ $do_update = 1 ]]; then
  wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -O download/S10W077.SRTMGL1.hgt.zip 'https://step.esa.int/auxdata/dem/SRTMGL1/S10W077.SRTMGL1.hgt.zip'
  unzip -d download download/S10W077.SRTMGL1.hgt.zip && rm download/S10W077.SRTMGL1.hgt.zip
  wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -O download/S10W078.SRTMGL1.hgt.zip 'https://step.esa.int/auxdata/dem/SRTMGL1/S10W078.SRTMGL1.hgt.zip'
  unzip -d download download/S10W078.SRTMGL1.hgt.zip && rm download/S10W078.SRTMGL1.hgt.zip
  wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -O download/S11W077.SRTMGL1.hgt.zip 'https://step.esa.int/auxdata/dem/SRTMGL1/S11W077.SRTMGL1.hgt.zip'
  unzip -d download download/S11W077.SRTMGL1.hgt.zip && rm download/S11W077.SRTMGL1.hgt.zip
  wget --load-cookies ~/.urs_cookies --save-cookies ~/.urs_cookies --keep-session-cookies -O download/S11W078.SRTMGL1.hgt.zip 'https://step.esa.int/auxdata/dem/SRTMGL1/S11W078.SRTMGL1.hgt.zip'
  unzip -d download download/S11W078.SRTMGL1.hgt.zip && rm download/S11W078.SRTMGL1.hgt.zip
  gdal_merge -o download/hh_dem_srtm_full.tif download/S10W077.hgt download/S10W078.hgt download/S11W077.hgt download/S11W078.hgt 
  gdalwarp -cutline 'POLYGON ((-77.33 -10.7, -77.33 -9.8, -76.55 -9.8, -76.55 -10.7, -77.33 -10.7))' -crop_to_cutline -cutline_srs EPSG:4326 -s_srs EPSG:4326 -t_srs EPSG:4326   download/hh_dem_srtm_full.tif download/hh_dem_srtm.tif && rm download/hh_dem_srtm_full.tif
fi
if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


