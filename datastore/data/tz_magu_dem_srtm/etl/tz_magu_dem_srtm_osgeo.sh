#!/bin/bash

# tz_magu_dem_srtm_osgeo.sh
# Download and ETL into postGIS from osgeo_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2025-09-07 17:36:05
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
# create directory structure and move into it
mkdir -p /data/tz_magu_dem_srtm/{download,etl} && cd /data/tz_magu_dem_srtm

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

wget --user $USGS_USER --password $USGS_PASSWORD -O download/S02E032.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S02E032.SRTMGL1.hgt.zip'
unzip -d download download/S02E032.SRTMGL1.hgt.zip && rm download/S02E032.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S02E033.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S02E033.SRTMGL1.hgt.zip'
unzip -d download download/S02E033.SRTMGL1.hgt.zip && rm download/S02E033.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S02E034.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S02E034.SRTMGL1.hgt.zip'
unzip -d download download/S02E034.SRTMGL1.hgt.zip && rm download/S02E034.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S03E032.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S03E032.SRTMGL1.hgt.zip'
unzip -d download download/S03E032.SRTMGL1.hgt.zip && rm download/S03E032.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S03E033.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S03E033.SRTMGL1.hgt.zip'
unzip -d download download/S03E033.SRTMGL1.hgt.zip && rm download/S03E033.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S03E034.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S03E034.SRTMGL1.hgt.zip'
unzip -d download download/S03E034.SRTMGL1.hgt.zip && rm download/S03E034.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S04E032.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S04E032.SRTMGL1.hgt.zip'
unzip -d download download/S04E032.SRTMGL1.hgt.zip && rm download/S04E032.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S04E033.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S04E033.SRTMGL1.hgt.zip'
unzip -d download download/S04E033.SRTMGL1.hgt.zip && rm download/S04E033.SRTMGL1.hgt.zip
wget --user $USGS_USER --password $USGS_PASSWORD -O download/S04E034.SRTMGL1.hgt.zip 'https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/S04E034.SRTMGL1.hgt.zip'
unzip -d download download/S04E034.SRTMGL1.hgt.zip && rm download/S04E034.SRTMGL1.hgt.zip
gdal_merge -o download/tz_magu_dem_srtm_full.tif download/S02E032.hgt download/S02E033.hgt download/S02E034.hgt download/S03E032.hgt download/S03E033.hgt download/S03E034.hgt download/S04E032.hgt download/S04E033.hgt download/S04E034.hgt 
gdalwarp -cutline 'POLYGON ((32.75 -3.09, 32.75 -2.13, 34.04 -2.13, 34.04 -3.09, 32.75 -3.09))' -crop_to_cutline -cutline_srs EPSG:4326 -s_srs EPSG:4326 -t_srs EPSG:4326 download/tz_magu_dem_srtm_full.tif download/tz_magu_dem_srtm.tif && rm download/tz_magu_dem_srtm_full.tif
