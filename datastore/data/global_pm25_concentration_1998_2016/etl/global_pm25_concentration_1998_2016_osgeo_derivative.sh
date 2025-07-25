#!/bin/bash

# global_pm25_concentration_1998_2016_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://sedac.ciesin.columbia.edu/downloads/data/sdei/sdei-annual-pm2-5-concentrations-countries-urban-areas-v1-1998-2016/sdei-annual-pm2-5-concentrations-countries-urban-areas-v1-1998-2016-urban-areas-shp.zip
# Destination postGIS table: global_pm25_concentration_1998_2016
#
# Created by etl() on 2025-06-30 18:24:27
# Do not edit directly

# Create derivative directory in data package on osgeo
cd /data/global_pm25_concentration_1998_2016/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" derived/global_pm25_concentration_1998_2016.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" global_pm25_concentration_1998_2016

# Create downloadable tarfile of shp in derivative directory on osgeo
tar -czf derived/global_pm25_concentration_1998_2016.shp.tar.gz meta_dcat_global_pm25_concentration_1998_2016.json -C derived global_pm25_concentration_1998_2016.shp global_pm25_concentration_1998_2016.prj global_pm25_concentration_1998_2016.shx global_pm25_concentration_1998_2016.dbf


