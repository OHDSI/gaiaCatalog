#!/bin/bash

# fl_superfund_waste_cleanup_sites_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/CLEANUP_SP/MapServer/1/query?where=1%3D1&outFields=*&outSR=4326&f=json
# Destination postGIS table: fl_superfund_waste_cleanup_sites
#
# Created by etl() on 2026-10-17 21:30:53
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
UPDATE fl_superfund_waste_cleanup_sites
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE fl_superfund_waste_cleanup_sites DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'fl_superfund_waste_cleanup_sites',
  'geom_local', 2236, 'point', 2
);
UPDATE fl_superfund_waste_cleanup_sites
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(geom,2236)));
CREATE INDEX fl_superfund_waste_cleanup_sites_geom_local_idx
  ON fl_superfund_waste_cleanup_sites
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
