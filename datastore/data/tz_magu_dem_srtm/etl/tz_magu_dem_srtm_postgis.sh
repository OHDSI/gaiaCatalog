#!/bin/bash

# tz_magu_dem_srtm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2025-10-05 15:59:47
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
(exit 1)
until [[ "$?" == 0 ]]; do
    cd /data/tz_magu_dem_srtm/download
    raster2pgsql -s 4326 -d -C -I -t auto tz_magu_dem_srtm.tif -F tz_magu_dem_srtm > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db < load_raster.sql
    rm load_raster.sql
    cd /data/tz_magu_dem_srtm
done

