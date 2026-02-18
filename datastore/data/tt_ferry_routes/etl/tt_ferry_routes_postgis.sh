#!/bin/bash

# tt_ferry_routes_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=way%5B%22route%22~%22ferry%22%5D(area:3600555717);(._;>;);out;
# Destination postGIS table: tt_ferry_routes
#
# Created by etl() on 2026-02-12 11:05:28
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO tt_ferry_routes FROM lines;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tt_ferry_routes
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tt_ferry_routes',
  'geom_local', 8035, 'multilinestring', 2
);
UPDATE tt_ferry_routes
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),8035)));
CREATE INDEX tt_ferry_routes_geom_local_idx
  ON tt_ferry_routes
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
