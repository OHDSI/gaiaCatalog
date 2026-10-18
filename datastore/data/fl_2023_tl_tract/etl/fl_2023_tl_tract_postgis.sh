#!/bin/bash

# fl_2023_tl_tract_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: ftp://ftp2.census.gov/geo/tiger/TIGER2023/TRACT/tl_2023_12_tract.zip
# Destination postGIS table: fl_2023_tl_tract
#
# Created by etl() on 2026-10-17 14:40:19
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
UPDATE fl_2023_tl_tract
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE fl_2023_tl_tract DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'fl_2023_tl_tract',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE fl_2023_tl_tract
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX fl_2023_tl_tract_geom_local_idx
  ON fl_2023_tl_tract
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
