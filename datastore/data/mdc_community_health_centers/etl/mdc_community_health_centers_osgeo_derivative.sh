#!/bin/bash

# mdc_community_health_centers_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/PaGISView_gdb/FeatureServer/0/query?where=DOR_DESC=%27CHARITABLE%20-%20EXEMPT%20:%20HEALTH%20CARE%27&outFields=*&outSR=4326&f=json&orderBy=ObjectId
# Destination postGIS table: mdc_community_health_centers
#
# Created by etl() on 2026-10-17 21:28:29
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_community_health_centers/
mkdir -p derived


