#!/bin/bash

# us_2019_prisecroads_tl_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://www2.census.gov/geo/tiger/TIGER2019/PRISECROADS/tl_2019_<state fips>_prisecroads.zip
# Destination postGIS table: us_2019_prisecroads_tl

psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE us_2019_prisecroads_tl
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));
ALTER TABLE us_2019_prisecroads_tl DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn ('us_2019_prisecroads_tl', 'geom_local', 4269, 'multilinestring', 2);
UPDATE us_2019_prisecroads_tl
  SET geom_local=ST_Multi(ST_Transform(geom,4269));
CREATE INDEX us_2019_prisecroads_tl_geom_local_idx ON us_2019_prisecroads_tl USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
" 2>&1
