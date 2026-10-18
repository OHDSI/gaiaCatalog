#!/bin/bash

# bogota_2019_estratos_manzana_dane_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://datosabiertos.bogota.gov.co/dataset/55467552-0af4-4524-a390-a2956035744e/resource/29f2d770-bd5d-4450-9e95-8737167ba12f/download/manzanaestratificacion.json
# Destination postGIS table: bogota_2019_estratos_manzana_dane
#
# Created by etl() on 2026-10-18 10:24:26
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
UPDATE bogota_2019_estratos_manzana_dane
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE bogota_2019_estratos_manzana_dane DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'bogota_2019_estratos_manzana_dane',
  'geom_local', 4686, 'multipolygon', 2
);
UPDATE bogota_2019_estratos_manzana_dane
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4686)));
CREATE INDEX bogota_2019_estratos_manzana_dane_geom_local_idx
  ON bogota_2019_estratos_manzana_dane
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
