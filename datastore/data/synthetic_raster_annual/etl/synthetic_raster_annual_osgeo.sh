#!/bin/bash

# synthetic_raster_annual_osgeo.sh
# Download the synthetic raster file(s); they are loaded into postGIS in the postgis step
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data
# Destination postGIS table: synthetic_raster_annual

mkdir -p /data/synthetic_raster_annual/download -p /data/synthetic_raster_annual/etl
chmod -R 777 /data/synthetic_raster_annual
cd /data/synthetic_raster_annual

do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  attempts=0
  until (
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2014.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2014.tif' 2>&1
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2015.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2015.tif' 2>&1
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2016.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2016.tif' 2>&1
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2017.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2017.tif' 2>&1
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2018.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2018.tif' 2>&1
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_annual_2019.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_annual_2019.tif' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; exit 1; fi
  done
  echo 'ef213ba4c7a3e69aeeda46ddea813e65ab72a21466542859cf079c21a18e8b17  download/synthetic_raster_annual_2014.tif' | sha256sum -c - || exit 1
  echo 'becb32b88479815d6ee9111bf3f2fb471bd91e393b32669c1badff72516b5059  download/synthetic_raster_annual_2015.tif' | sha256sum -c - || exit 1
  echo '7aabf051d8883140d28d493d474377b320c3fab2a168f8a971c0bb7ce52371a1  download/synthetic_raster_annual_2016.tif' | sha256sum -c - || exit 1
  echo 'e781b81d588ddc6a18106fa65cbfdf27b0c64b7d18e37796095e98f7cf3cf943  download/synthetic_raster_annual_2017.tif' | sha256sum -c - || exit 1
  echo '27f274a846ee055f6aead084a3fcdc5cc131b5dda2acb44834a4453b774f384a  download/synthetic_raster_annual_2018.tif' | sha256sum -c - || exit 1
  echo '1f45681ec031daa2eb8c60dd12a96c2e7c27c05e8dc64abf3e70815d5e8e4c3a  download/synthetic_raster_annual_2019.tif' | sha256sum -c - || exit 1
  echo $(date '+%F %T') > datestamp
fi
