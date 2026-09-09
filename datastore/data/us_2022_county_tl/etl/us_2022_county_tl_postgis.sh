#!/bin/bash

# us_2022_county_tl_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: ftp://ftp2.census.gov/geo/tiger/TIGER2022/COUNTY/tl_2022_us_county.zip
# Destination postGIS table: us_2022_county_tl
#
# Created by etl() on 2026-09-08 22:17:12
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE us_2022_county_tl
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'us_2022_county_tl',
  'geom_local', 4269, 'multipolygon', 2
);
UPDATE us_2022_county_tl
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4269)));
CREATE INDEX us_2022_county_tl_geom_local_idx
  ON us_2022_county_tl
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
