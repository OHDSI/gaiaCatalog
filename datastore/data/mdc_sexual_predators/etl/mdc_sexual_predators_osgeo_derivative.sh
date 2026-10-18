#!/bin/bash

# mdc_sexual_predators_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/SEXPRED_gdb/FeatureServer/0/query?outFields=*&where=1%3D1&outSR=4326&f=geojson
# Destination postGIS table: mdc_sexual_predators
#
# Created by etl() on 2026-10-17 21:31:28
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_sexual_predators/
mkdir -p derived


