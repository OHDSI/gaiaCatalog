#!/bin/bash

# fl_2022_tl_cousub_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: ftp://ftp2.census.gov/geo/tiger/TIGER2022/COUSUB/tl_2022_12_cousub.zip
# Destination postGIS table: fl_2022_tl_cousub
#
# Created by etl() on 2026-10-19 08:24:32
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
UPDATE fl_2022_tl_cousub
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE fl_2022_tl_cousub DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'fl_2022_tl_cousub',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE fl_2022_tl_cousub
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX fl_2022_tl_cousub_geom_local_idx
  ON fl_2022_tl_cousub
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
