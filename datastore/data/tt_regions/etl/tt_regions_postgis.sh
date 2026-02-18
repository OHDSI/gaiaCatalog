#!/bin/bash

# tt_regions_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=rel%5B%22ISO3166-2%22~%22^TT%22%5D%5Badmin_level=4%5D%5Btype=boundary%5D%5Bboundary=administrative%5D;(._;>;);out;
# Destination postGIS table: tt_regions
#
# Created by etl() on 2026-02-12 11:05:10
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO tt_regions FROM multipolygons;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tt_regions
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tt_regions',
  'geom_local', 8035, 'multipolygon', 2
);
UPDATE tt_regions
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),8035)));
CREATE INDEX tt_regions_geom_local_idx
  ON tt_regions
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
