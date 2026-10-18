#!/bin/bash

# mdc_municipal_park_boundaries_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://opendata.arcgis.com/api/v3/datasets/16fe02a1defa45b28bf14a29fb5f0428_0/downloads/data?format=geojson&spatialRefId=4326&where=1%3D1
# Destination postGIS table: mdc_municipal_park_boundaries
#
# Created by etl() on 2026-10-09 22:52:53
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE mdc_municipal_park_boundaries
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_municipal_park_boundaries DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_municipal_park_boundaries',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE mdc_municipal_park_boundaries
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX mdc_municipal_park_boundaries_geom_local_idx
  ON mdc_municipal_park_boundaries
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
