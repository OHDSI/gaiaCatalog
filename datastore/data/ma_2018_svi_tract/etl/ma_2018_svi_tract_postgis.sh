#!/bin/bash

# ma_2018_svi_tract_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip
# Destination postGIS table: ma_2018_svi_tract
#
# Created by etl() on 2026-09-11 21:42:54
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
UPDATE ma_2018_svi_tract
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE ma_2018_svi_tract DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'ma_2018_svi_tract',
  'geom_local', 26986, 'multipolygon', 2
);
UPDATE ma_2018_svi_tract
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),26986)));
CREATE INDEX ma_2018_svi_tract_geom_local_idx
  ON ma_2018_svi_tract
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
