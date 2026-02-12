#!/bin/bash

# tt_populated_places_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=node%5B%22place%22~%22city|town|village%22%5D(area:3600555717);(._;>;);out;
# Destination postGIS table: tt_populated_places
#
# Created by etl() on 2026-02-12 11:05:34
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO tt_populated_places FROM points;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tt_populated_places
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tt_populated_places',
  'geom_local', 8035, 'point', 2
);
UPDATE tt_populated_places
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(geom,8035)));
CREATE INDEX tt_populated_places_geom_local_idx
  ON tt_populated_places
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
