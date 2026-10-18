#!/bin/bash

# hh_rutas_pie_osm_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=%28nwr%5B%22highway%22=%22path%22%5D%28-10.7,-77.33,-9.8,-76.55%29;nwr%5B%22highway%22=%22footway%22%5D%5B%22footway%22=%22trail%22%5D%28-10.7,-77.33,-9.8,-76.55%29;nwr%5B%22route%22=%22hiking%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%29;%28._;>;%29;out;
# Destination postGIS table: hh_rutas_pie_osm
#
# Created by etl() on 2026-10-17 21:44:47
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# Select proper geometry into the named table
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT * INTO hh_rutas_pie_osm FROM lines;
DROP TABLE IF EXISTS lines;
DROP TABLE IF EXISTS multilinestrings;
DROP TABLE IF EXISTS multipolygons;
DROP TABLE IF EXISTS other_relations;
DROP TABLE IF EXISTS points;"

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE hh_rutas_pie_osm
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE hh_rutas_pie_osm DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'hh_rutas_pie_osm',
  'geom_local', 5387, 'multilinestring', 2
);
UPDATE hh_rutas_pie_osm
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),5387)));
CREATE INDEX hh_rutas_pie_osm_geom_local_idx
  ON hh_rutas_pie_osm
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
