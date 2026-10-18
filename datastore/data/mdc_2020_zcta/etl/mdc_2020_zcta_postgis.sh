#!/bin/bash

# mdc_2020_zcta_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: ftp://ftp2.census.gov/geo/tiger/TIGER2020/ZCTA520/tl_2020_us_zcta520.zip
# Destination postGIS table: mdc_2020_zcta
#
# Created by etl() on 2026-10-10 20:56:11
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# clip as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
CREATE TABLE mdc_2020_zcta AS
SELECT us_2020_zcta.ogc_fid, us_2020_zcta.geoid20, us_2020_zcta.zcta5ce20, us_2020_zcta.classfp20, us_2020_zcta.mtfcc20, us_2020_zcta.aland20, us_2020_zcta.awater20, us_2020_zcta.funcstat20, us_2020_zcta.intptlat20, us_2020_zcta.intptlon20, us_2020_zcta.geom
FROM us_2020_zcta
JOIN us_2020_county_tl on ST_Intersects(us_2020_zcta.geom, us_2020_county_tl.geom)
WHERE us_2020_county_tl.geoid = '12086';
COMMIT;"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE mdc_2020_zcta DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'mdc_2020_zcta',
  'geom_local', 4269, 'multipolygon', 2
);
UPDATE mdc_2020_zcta
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4269)));
CREATE INDEX mdc_2020_zcta_geom_local_idx
  ON mdc_2020_zcta
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
