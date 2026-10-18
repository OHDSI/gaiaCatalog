#!/bin/bash

# mdc_sexual_predators_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/SEXPRED_gdb/FeatureServer/0/query?outFields=*&where=1%3D1&outSR=4326&f=geojson
# Destination postGIS table: mdc_sexual_predators
#
# Created by etl() on 2026-10-17 21:31:28
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
UPDATE mdc_sexual_predators
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_sexual_predators DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_sexual_predators',
  'geom_local', 2236, 'point', 2
);
UPDATE mdc_sexual_predators
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(geom,2236)));
CREATE INDEX mdc_sexual_predators_geom_local_idx
  ON mdc_sexual_predators
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
