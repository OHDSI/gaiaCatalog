#!/bin/bash

# hh_rios_arroyos_osm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=nwr%5B%22waterway%22~%22river|stream%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%28._;>;%29;out;
# Destination postGIS table: hh_rios_arroyos_osm
#
# Created by etl() on 2026-10-17 21:43:13
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_rios_arroyos_osm/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/hh_rios_arroyos_osm.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" hh_rios_arroyos_osm

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/hh_rios_arroyos_osm.shp.tar.gz
tar -czf derived/hh_rios_arroyos_osm.shp.tar.gz meta_dcat_hh_rios_arroyos_osm.json -C derived hh_rios_arroyos_osm.shp hh_rios_arroyos_osm.prj hh_rios_arroyos_osm.shx hh_rios_arroyos_osm.dbf

# Create gpkg of table in derivate directory on osgeo 
rm -f derived/hh_rios_arroyos_osm.gpkg
ogr2ogr -f GPKG -overwrite derived/hh_rios_arroyos_osm.gpkg PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "osm_id,name,destination,intermittent,length,name:en,name:qu,waterway,geom" hh_rios_arroyos_osm

# Create downloadable tarfile of gpkg in derivative directory on osgeo
rm -f derived/hh_rios_arroyos_osm.gpkg.tar.gz
tar -czf derived/hh_rios_arroyos_osm.gpkg.tar.gz meta_dcat_hh_rios_arroyos_osm.json -C derived hh_rios_arroyos_osm.gpkg

# Create geojson of table in derivate directory on osgeo 
rm -f derived/hh_rios_arroyos_osm.json
ogr2ogr -f GeoJSON -overwrite derived/hh_rios_arroyos_osm.json PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "osm_id,name,destination,intermittent,length,name:en,name:qu,waterway,geom" hh_rios_arroyos_osm

# Create downloadable tarfile of geojson in derivative directory on osgeo
rm -f derived/hh_rios_arroyos_osm.geojson.tar.gz
tar -czf derived/hh_rios_arroyos_osm.geojson.tar.gz meta_dcat_hh_rios_arroyos_osm.json -C derived hh_rios_arroyos_osm.json


