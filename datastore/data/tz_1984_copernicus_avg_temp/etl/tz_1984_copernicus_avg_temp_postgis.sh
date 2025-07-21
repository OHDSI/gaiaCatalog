#!/bin/bash

# tz_1984_copernicus_avg_temp_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2025-06-29 21:32:26
# Do not edit directly

(exit 1)
until [[ "$?" == 0 ]]; do
    cd /data/tz_1984_copernicus_avg_temp/download
    raster2pgsql -s 4326 -d -C -I -t auto tz_1984_copernicus_avg_temp.tif -F tz_1984_copernicus_avg_temp > load_raster.sql
    psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h postgis-mvznqevo8s0vzrl3 < load_raster.sql
    rm load_raster.sql
    cd /data/tz_1984_copernicus_avg_temp
done

