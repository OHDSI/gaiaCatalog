#!/bin/bash

# hh_lagunas_ana_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://geosnirh.ana.gob.pe/server/rest/services/P%C3%BAblico/Lagunas/MapServer/36/query?where=1%3D1&geometry=%22xmin%22%3A-77.33%2C%22ymin%22%3A-10.7%2C%22xmax%22%3A-76.55%2C%22ymax%22%3A-9.8&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=4326&f=geojson
# Destination postGIS table: hh_lagunas_ana
#
# Created by etl() on 2026-10-17 21:42:50
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_lagunas_ana/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/hh_lagunas_ana.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" hh_lagunas_ana

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/hh_lagunas_ana.shp.tar.gz
tar -czf derived/hh_lagunas_ana.shp.tar.gz meta_dcat_hh_lagunas_ana.json -C derived hh_lagunas_ana.shp hh_lagunas_ana.prj hh_lagunas_ana.shx hh_lagunas_ana.dbf

# Create gpkg of table in derivate directory on osgeo 
rm -f derived/hh_lagunas_ana.gpkg
ogr2ogr -f GPKG -overwrite derived/hh_lagunas_ana.gpkg PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "id,nombreoficial,ubigeo,nombrecuerpo,codala,ala,codaaa,aaa,coordillera,fechaimagensatelital,fuente,geom,codigouh,nombreuh,geom" hh_lagunas_ana

# Create downloadable tarfile of gpkg in derivative directory on osgeo
rm -f derived/hh_lagunas_ana.gpkg.tar.gz
tar -czf derived/hh_lagunas_ana.gpkg.tar.gz meta_dcat_hh_lagunas_ana.json -C derived hh_lagunas_ana.gpkg

# Create geojson of table in derivate directory on osgeo 
rm -f derived/hh_lagunas_ana.json
ogr2ogr -f GeoJSON -overwrite derived/hh_lagunas_ana.json PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "id,nombreoficial,ubigeo,nombrecuerpo,codala,ala,codaaa,aaa,coordillera,fechaimagensatelital,fuente,geom,codigouh,nombreuh,geom" hh_lagunas_ana

# Create downloadable tarfile of geojson in derivative directory on osgeo
rm -f derived/hh_lagunas_ana.geojson.tar.gz
tar -czf derived/hh_lagunas_ana.geojson.tar.gz meta_dcat_hh_lagunas_ana.json -C derived hh_lagunas_ana.json


