#!/bin/bash

# mdc_holc_redlining_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://services.arcgis.com/jIL9msH9OI208GCb/ArcGIS/rest/services/HOLC_Neighborhood_Redlining/FeatureServer/0/query?where=city=%27Miami%27&outFields=*&outSR=4326&f=json
# Destination postGIS table: mdc_holc_redlining
#
# Created by etl() on 2026-10-17 21:22:28
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_holc_redlining/
mkdir -p derived


