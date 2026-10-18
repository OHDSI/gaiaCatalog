#!/bin/bash

# egom_2013_viirs_vnp46a4_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://ladsweb.modaps.eosdis.nasa.gov/api/v2/content/archives/VNP46A4.A2013001.h09v06.002.2025087045108.h5
# Destination postGIS table: egom_2013_viirs_vnp46a4
#
# Created by etl() on 2026-10-17 21:53:42
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# create directory structure and move into it
mkdir -p /data/egom_2013_viirs_vnp46a4/download -p /data/egom_2013_viirs_vnp46a4/etl
chmod -R 777 /data/egom_2013_viirs_vnp46a4
cd /data/egom_2013_viirs_vnp46a4

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
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi

# load into postGIS
cd download
gdalinfo HDF5:"VNP46A4.A2013001.h09v06.002.2025087045108.h5.h5"://HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data_Fields/NearNadir_Composite_Snow_Free | grep BoundingCoord > bounds.txt
gdal_translate -a_srs EPSG:4326 -a_ullr $(cat bounds.txt | grep West | cut -d = -f 2) $(cat bounds.txt | grep North | cut -d = -f 2) $(cat bounds.txt | grep East | cut -d = -f 2) $(cat bounds.txt | grep South | cut -d = -f 2) HDF5:"VNP46A4.A2013001.h09v06.002.2025087045108.h5.h5"://HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data_Fields/NearNadir_Composite_Snow_Free VNP46A4.A2013001.h09v06.002.2025087045108.h5.tif
rm bounds.txt
cd ..

if [[ $do_update = 1 ]]; then
  # record download datestamp
  echo $(date '+%F %T') > datestamp
fi


