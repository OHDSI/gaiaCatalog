#!/bin/bash

# mdc_2026_flma_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: fl_2026_flma
# Destination postGIS table: mdc_2026_flma
#
# Created by etl() on 2026-10-09 22:52:48
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t fl_2026_flma | sed 's/fl_2026_flma/mdc_2026_flma/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# drop geom_local and subset as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2026_flma DROP COLUMN IF EXISTS geom_local;
DELETE FROM mdc_2026_flma
  WHERE NOT (county = 'Miami-Dade');
COMMIT;"
# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2026_flma DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_2026_flma',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE mdc_2026_flma
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX mdc_2026_flma_geom_local_idx
  ON mdc_2026_flma
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2026_flma DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_2026_flma',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE mdc_2026_flma
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX mdc_2026_flma_geom_local_idx
  ON mdc_2026_flma
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
