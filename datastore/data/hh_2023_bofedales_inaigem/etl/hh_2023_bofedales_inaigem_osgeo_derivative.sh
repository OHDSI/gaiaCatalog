#!/bin/bash

# hh_2023_bofedales_inaigem_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://datacochageoespacial.inaigem.gob.pe/geoserver/inventario_bofedales/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=inventario_bofedales%3Ainventario_bofedales_2023&outputFormat=application/json&bbox=-77.33,-10.7,-76.55,-9.8,EPSG:4326
# Destination postGIS table: hh_2023_bofedales_inaigem
#
# Created by etl() on 2026-10-17 21:41:48
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/hh_2023_bofedales_inaigem/
mkdir -p derived

# Create shapefile of table in derivate directory on osgeo 
ogr2ogr -f "ESRI Shapefile" -overwrite derived/hh_2023_bofedales_inaigem.shp PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" hh_2023_bofedales_inaigem

# Create downloadable tarfile of shp in derivative directory on osgeo
rm -f derived/hh_2023_bofedales_inaigem.shp.tar.gz
tar -czf derived/hh_2023_bofedales_inaigem.shp.tar.gz meta_dcat_hh_2023_bofedales_inaigem.json -C derived hh_2023_bofedales_inaigem.shp hh_2023_bofedales_inaigem.prj hh_2023_bofedales_inaigem.shx hh_2023_bofedales_inaigem.dbf

# Create gpkg of table in derivate directory on osgeo 
rm -f derived/hh_2023_bofedales_inaigem.gpkg
ogr2ogr -f GPKG -overwrite derived/hh_2023_bofedales_inaigem.gpkg PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "objectid,fid_invent,desc_cober,zona_utm,macrozona,vertiente,ubig_dep,nomb_dep,ubig_prov,nomb_prov,ubig_dist,nomb_dist,nomb_capdi,cod_uh,nomb_uh,area_ha,geom" hh_2023_bofedales_inaigem

# Create downloadable tarfile of gpkg in derivative directory on osgeo
rm -f derived/hh_2023_bofedales_inaigem.gpkg.tar.gz
tar -czf derived/hh_2023_bofedales_inaigem.gpkg.tar.gz meta_dcat_hh_2023_bofedales_inaigem.json -C derived hh_2023_bofedales_inaigem.gpkg

# Create geojson of table in derivate directory on osgeo 
rm -f derived/hh_2023_bofedales_inaigem.json
ogr2ogr -f GeoJSON -overwrite derived/hh_2023_bofedales_inaigem.json PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "objectid,fid_invent,desc_cober,zona_utm,macrozona,vertiente,ubig_dep,nomb_dep,ubig_prov,nomb_prov,ubig_dist,nomb_dist,nomb_capdi,cod_uh,nomb_uh,area_ha,geom" hh_2023_bofedales_inaigem

# Create downloadable tarfile of geojson in derivative directory on osgeo
rm -f derived/hh_2023_bofedales_inaigem.geojson.tar.gz
tar -czf derived/hh_2023_bofedales_inaigem.geojson.tar.gz meta_dcat_hh_2023_bofedales_inaigem.json -C derived hh_2023_bofedales_inaigem.json


