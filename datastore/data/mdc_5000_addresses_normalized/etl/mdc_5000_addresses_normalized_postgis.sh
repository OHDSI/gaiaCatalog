#!/bin/bash

# mdc_5000_addresses_normalized_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: file:///data/mdc_5000_addresses_normalized/download/mdc_5000_addresses_normalized
# Destination postGIS table: mdc_5000_addresses_normalized
#
# Created by etl() on 2026-10-17 21:39:10
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
UPDATE mdc_5000_addresses_normalized
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_5000_addresses_normalized DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_5000_addresses_normalized',
  'geom_local', 2236, 'point', 2
);
UPDATE mdc_5000_addresses_normalized
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(geom,2236)));
CREATE INDEX mdc_5000_addresses_normalized_geom_local_idx
  ON mdc_5000_addresses_normalized
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
