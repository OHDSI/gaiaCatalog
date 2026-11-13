#!/bin/bash

# synthetic_raster_landcover_osgeo.sh
# Download the synthetic raster file(s); they are loaded into postGIS in the postgis step
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data
# Destination postGIS table: synthetic_raster_landcover

mkdir -p /data/synthetic_raster_landcover/download -p /data/synthetic_raster_landcover/etl
chmod -R 777 /data/synthetic_raster_landcover
cd /data/synthetic_raster_landcover

do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  attempts=0
  until (
  wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_raster_landcover.tif 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/raster/data/synthetic_raster_landcover.tif' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; exit 1; fi
  done
  echo $(date '+%F %T') > datestamp
fi
