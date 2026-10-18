#!/bin/bash

# mdc_2022_svi_tract_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2022/db/states/Florida.zip
# Destination postGIS table: mdc_2022_svi_tract
#
# Created by etl() on 2026-10-09 22:52:33
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_2022_svi_tract/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/mdc_2022_svi_tract.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" mdc_2022_svi_tract

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/mdc_2022_svi_tract.shp.tar.gz
tar -czf derived/mdc_2022_svi_tract.shp.tar.gz meta_dcat_mdc_2022_svi_tract.json -C derived mdc_2022_svi_tract.shp mdc_2022_svi_tract.prj mdc_2022_svi_tract.shx mdc_2022_svi_tract.dbf


