#!/bin/bash

# tz_magu_dem_srtm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2026-09-06 12:36:47
# Do not edit directly

attempts=0
until (
    cd /data/tz_magu_dem_srtm/download
    raster2pgsql -s 4326 -d -C -I -t auto tz_magu_dem_srtm.tif -F tz_magu_dem_srtm > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    rm load_raster.sql
    cd /data/tz_magu_dem_srtm
); do
  ((attempts++))
  if [[ attempts > 3 ]]; then echo $?; break; fi
done

