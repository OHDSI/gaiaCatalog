#!/bin/bash

# synthetic_raster_surface_1km_postgis.sh
# Load the raster file(s) into public.synthetic_raster_surface_1km (column rast, one row per tile, filename of the source file)

cd /data/synthetic_raster_surface_1km/download
raster2pgsql -s 5070 -d -C -I -M -F -t 64x64 synthetic_raster_surface_1km.tif public.synthetic_raster_surface_1km \
  | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -q
echo success: synthetic_raster_surface_1km.tif loaded with raster2pgsql
