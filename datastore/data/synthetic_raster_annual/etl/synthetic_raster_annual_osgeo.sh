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
  echo $(date '+%F %T') > datestamp
fi
