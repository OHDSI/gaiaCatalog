#!/bin/bash

# tz_2022_nbs_districts_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://microdata.nbs.go.tz/index.php/catalog/49/download/317
# Destination postGIS table: tz_2022_nbs_districts
#
# Created by etl() on 2025-09-07 17:36:06
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_2022_nbs/tz_2022_nbs_districts/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/tz_2022_nbs_districts.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" tz_2022_nbs_districts

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/tz_2022_nbs_districts.shp.tar.gz
tar -czf derived/tz_2022_nbs_districts.shp.tar.gz meta_dcat_tz_2022_nbs_districts.json -C derived tz_2022_nbs_districts.shp tz_2022_nbs_districts.prj tz_2022_nbs_districts.shx tz_2022_nbs_districts.dbf


