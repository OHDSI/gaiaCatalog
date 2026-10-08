#!/bin/bash

# us_2019_tract_tl_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://www2.census.gov/geo/tiger/TIGER2019/TRACT/tl_2019_<state fips>_tract.zip
# Destination postGIS table: us_2019_tract_tl

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE us_2019_tract_tl
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));" 2>&1

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE us_2019_tract_tl DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'us_2019_tract_tl',
  'geom_local', 4269, 'multipolygon', 2
);
UPDATE us_2019_tract_tl
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4269)));
CREATE INDEX us_2019_tract_tl_geom_local_idx
  ON us_2019_tract_tl
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
" 2>&1
