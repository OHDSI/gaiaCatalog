#!/bin/bash

# mdc_federally_qualified_health_centers_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/FederallyQualifiedHealthCenter_gdb/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json
# Destination postGIS table: mdc_federally_qualified_health_centers
#
# Created by etl() on 2026-10-17 21:28:13
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_federally_qualified_health_centers/
mkdir -p derived


