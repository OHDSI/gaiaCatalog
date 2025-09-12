#!/bin/bash

# tz_regions_osm_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=rel%5B%22ISO3166-2%22~%22^TZ%22%5D%5Badmin_level=4%5D%5Btype=boundary%5D%5Bboundary=administrative%5D;(._;>;);out;
# Destination postGIS table: tz_regions_osm
#
# Created by etl() on 2025-09-11 18:03:34
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/tz_regions_osm/
mkdir -p derived

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/tz_regions_osm.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" tz_regions_osm

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/tz_regions_osm.shp.tar.gz
tar -czf derived/tz_regions_osm.shp.tar.gz meta_dcat_tz_regions_osm.json -C derived tz_regions_osm.shp tz_regions_osm.prj tz_regions_osm.shx tz_regions_osm.dbf


