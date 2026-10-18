#!/bin/bash

# hh_lagunas_ana_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://geosnirh.ana.gob.pe/server/rest/services/P%C3%BAblico/Lagunas/MapServer/36/query?where=1%3D1&geometry=%22xmin%22%3A-77.33%2C%22ymin%22%3A-10.7%2C%22xmax%22%3A-76.55%2C%22ymax%22%3A-9.8&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=*&returnGeometry=true&outSR=4326&f=geojson
# Destination postGIS table: hh_lagunas_ana
#
# Created by etl() on 2026-10-17 21:42:50
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
UPDATE hh_lagunas_ana
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE hh_lagunas_ana DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'hh_lagunas_ana',
  'geom_local', 5387, 'multipolygon', 2
);
UPDATE hh_lagunas_ana
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),5387)));
CREATE INDEX hh_lagunas_ana_geom_local_idx
  ON hh_lagunas_ana
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
