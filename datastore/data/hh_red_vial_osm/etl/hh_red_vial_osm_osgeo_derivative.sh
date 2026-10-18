#!/bin/bash

# hh_red_vial_osm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=%28nwr%5B%22highway%22~%22primary|secondary|tertiary|unclassified|residential|service|track%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%29;%28._;%3E;%29;out;
# Destination postGIS table: hh_red_vial_osm
#
# Created by etl() on 2026-10-17 21:44:54
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_red_vial_osm/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/hh_red_vial_osm.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" hh_red_vial_osm

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/hh_red_vial_osm.shp.tar.gz
tar -czf derived/hh_red_vial_osm.shp.tar.gz meta_dcat_hh_red_vial_osm.json -C derived hh_red_vial_osm.shp hh_red_vial_osm.prj hh_red_vial_osm.shx hh_red_vial_osm.dbf

# Create gpkg of table in derivate directory on osgeo 
rm -f derived/hh_red_vial_osm.gpkg
ogr2ogr -f GPKG -overwrite derived/hh_red_vial_osm.gpkg PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "osm_id,name,highway,other_tags,geom" hh_red_vial_osm

# Create downloadable tarfile of gpkg in derivative directory on osgeo
rm -f derived/hh_red_vial_osm.gpkg.tar.gz
tar -czf derived/hh_red_vial_osm.gpkg.tar.gz meta_dcat_hh_red_vial_osm.json -C derived hh_red_vial_osm.gpkg

# Create geojson of table in derivate directory on osgeo 
rm -f derived/hh_red_vial_osm.json
ogr2ogr -f GeoJSON -overwrite derived/hh_red_vial_osm.json PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "osm_id,name,highway,other_tags,geom" hh_red_vial_osm

# Create downloadable tarfile of geojson in derivative directory on osgeo
rm -f derived/hh_red_vial_osm.geojson.tar.gz
tar -czf derived/hh_red_vial_osm.geojson.tar.gz meta_dcat_hh_red_vial_osm.json -C derived hh_red_vial_osm.json


