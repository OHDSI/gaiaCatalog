#!/bin/bash

# tz_magu_dem_srtm_render.sh
# Finish ETL into postGIS from render_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2025-09-11 18:03:33
# Do not edit directly

# render raster tiles 
cd /data/tz_magu_dem_srtm/
gdal2tiles.py -ex --xyz -z 14-18 /data/tz_magu_dem_srtm/download/tz_magu_dem_srtm.tif /tiles/raster/tz_magu_dem_srtm

