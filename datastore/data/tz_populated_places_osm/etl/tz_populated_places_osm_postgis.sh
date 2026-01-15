#!/bin/bash

# tz_populated_places_osm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=area%28id:3600195270%29-%3E.searchArea;node%5B%22place%22~%22city|town|village|hamlet%22%5D%28area.searchArea%29;%28._;%3E;%29;out;
# Destination postGIS table: tz_populated_places_osm
#
# Created by etl() on 2025-10-05 15:59:50
# Do not edit directly

# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO tz_populated_places_osm FROM points;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tz_populated_places_osm
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tz_populated_places_osm',
  'geom_local', 4326, 'point', 2
);
UPDATE tz_populated_places_osm
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(geom,4326)));
CREATE INDEX tz_populated_places_osm_geom_local_idx
  ON tz_populated_places_osm
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
