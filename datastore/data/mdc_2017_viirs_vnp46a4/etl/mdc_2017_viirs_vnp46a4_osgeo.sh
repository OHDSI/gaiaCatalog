#!/bin/bash

# mdc_2017_viirs_vnp46a4_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://ladsweb.modaps.eosdis.nasa.gov/api/v2/content/archives/VNP46A4.A2017001.h09v06.002.2025105122545.h5
# Destination postGIS table: mdc_2017_viirs_vnp46a4
#
# Created by etl() on 2026-10-17 21:54:04
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/mdc_2017_viirs_vnp46a4/download -p /data/mdc_2017_viirs_vnp46a4/etl
chmod -R 777 /data/mdc_2017_viirs_vnp46a4
cd /data/mdc_2017_viirs_vnp46a4

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

# clip source raster and reproject as needed
if [[ $do_update = 1 ]]; then
  gdalwarp -cutline PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host=gaia-db" -csql "SELECT geom FROM fl_2022_tl_cousub WHERE countyfp='086'" -crop_to_cutline -s_srs EPSG:4326 -t_srs EPSG:4326 -srcnodata 65535 -dstnodata 65535 /data/egom_2017_viirs_vnp46a4/download/VNP46A4.A2017001.h09v06.002.2025105122545.h5.tif download/VNP46A4.A2017001.h09v06.002.2025105122545.tif
fi
if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


