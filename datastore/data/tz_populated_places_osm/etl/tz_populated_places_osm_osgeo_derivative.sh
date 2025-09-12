#!/bin/bash

# tz_populated_places_osm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=area%28id:3600195270%29-%3E.searchArea;node%5B%22place%22~%22city|town|village|hamlet%22%5D%28area.searchArea%29;%28._;%3E;%29;out;
# Destination postGIS table: tz_populated_places_osm
#
# Created by etl() on 2025-09-11 18:03:33
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_populated_places_osm/
mkdir -p derived

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/tz_populated_places_osm.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" tz_populated_places_osm

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/tz_populated_places_osm.shp.tar.gz
tar -czf derived/tz_populated_places_osm.shp.tar.gz meta_dcat_tz_populated_places_osm.json -C derived tz_populated_places_osm.shp tz_populated_places_osm.prj tz_populated_places_osm.shx tz_populated_places_osm.dbf


