#!/bin/bash

# hh_lagunas_ana_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://geosnirh.ana.gob.pe/server/rest/services/P%C3%BAblico/Lagunas/MapServer/36/query?where=1%3D1&geometry=%22xmin%22%3A-77.33%2C%22ymin%22%3A-10.7%2C%22xmax%22%3A-76.55%2C%22ymax%22%3A-9.8&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=4326&f=geojson
# Destination postGIS table: hh_lagunas_ana
#
# Created by etl() on 2026-10-17 21:42:50
# Do not edit directly

# Move into correct directory
cd /data/hh_lagunas_ana/


