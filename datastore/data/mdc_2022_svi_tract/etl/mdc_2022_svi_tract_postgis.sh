#!/bin/bash

# mdc_2022_svi_tract_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2022/db/states/Florida.zip
# Destination postGIS table: mdc_2022_svi_tract
#
# Created by etl() on 2026-10-09 22:52:33
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t fl_2022_svi_tract | sed 's/fl_2022_svi_tract/mdc_2022_svi_tract/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# drop geom_local and subset as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2022_svi_tract DROP COLUMN IF EXISTS geom_local;
DELETE FROM mdc_2022_svi_tract
  WHERE NOT (stcnty = '12086');
COMMIT;"
# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2022_svi_tract DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_2022_svi_tract',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE mdc_2022_svi_tract
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX mdc_2022_svi_tract_geom_local_idx
  ON mdc_2022_svi_tract
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2022_svi_tract DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_2022_svi_tract',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE mdc_2022_svi_tract
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX mdc_2022_svi_tract_geom_local_idx
  ON mdc_2022_svi_tract
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
