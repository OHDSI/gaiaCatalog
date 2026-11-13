#!/bin/bash

# synthetic_monitors_200_voronoi_osgeo.sh
# Nothing to download: the cells are derived from synthetic_monitors_200, which has to be ingested first

exists=$(psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -tAc "SELECT to_regclass('public.synthetic_monitors_200') IS NOT NULL")
if [[ "$exists" != "t" ]]; then
  echo "synthetic_monitors_200_voronoi is derived from synthetic_monitors_200: run backbone.ingest_datasource('synthetic_monitors_200') first" >&2
  exit 1
fi
echo success: synthetic_monitors_200 found
