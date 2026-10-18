#!/bin/bash

# hh_dem_srtm_render.sh
# Finish ETL into postGIS from render_postgis container
#
# Data source: https://step.esa.int/auxdata/dem/SRTMGL1/
# Destination postGIS table: hh_dem_srtm
#
# Created by etl() on 2026-10-17 21:44:25
# Do not edit directly

# render raster tiles 
cd /data/hh_dem_srtm/
gdal2tiles.py -ex --xyz -z 14-18 /data/hh_dem_srtm/download/hh_dem_srtm.tif /tiles/raster/hh_dem_srtm

