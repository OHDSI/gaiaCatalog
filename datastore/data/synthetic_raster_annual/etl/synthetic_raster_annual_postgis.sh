#!/bin/bash

# synthetic_raster_annual_postgis.sh
# Load the raster file(s) into public.synthetic_raster_annual (column rast, one row per tile, filename of the source file)

cd /data/synthetic_raster_annual/download
raster2pgsql -s 5070 -d -C -I -M -F -t 64x64 synthetic_raster_annual_2014.tif synthetic_raster_annual_2015.tif synthetic_raster_annual_2016.tif synthetic_raster_annual_2017.tif synthetic_raster_annual_2018.tif synthetic_raster_annual_2019.tif public.synthetic_raster_annual \
  | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -q
echo success: synthetic_raster_annual_2014.tif synthetic_raster_annual_2015.tif synthetic_raster_annual_2016.tif synthetic_raster_annual_2017.tif synthetic_raster_annual_2018.tif synthetic_raster_annual_2019.tif loaded with raster2pgsql
