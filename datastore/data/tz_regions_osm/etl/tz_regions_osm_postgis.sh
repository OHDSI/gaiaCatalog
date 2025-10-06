#!/bin/bash

# tz_regions_osm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=rel%5B%22ISO3166-2%22~%22^TZ%22%5D%5Badmin_level=4%5D%5Btype=boundary%5D%5Bboundary=administrative%5D;(._;>;);out;
# Destination postGIS table: tz_regions_osm
#
# Created by etl() on 2025-10-05 15:59:50
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO tz_regions_osm FROM multipolygons;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tz_regions_osm
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tz_regions_osm',
  'geom_local', 4326, 'multipolygon', 2
);
UPDATE tz_regions_osm
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4326)));
CREATE INDEX tz_regions_osm_geom_local_idx
  ON tz_regions_osm
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
