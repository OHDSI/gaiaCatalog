#!/bin/bash

# tz_2022_nbs_magu_district_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: tz_2022_nbs_districts
# Destination postGIS table: tz_2022_nbs_magu_district
#
# Created by etl() on 2026-02-10 13:37:47
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h None -t tz_2022_nbs_districts | sed 's/tz_2022_nbs_districts/tz_2022_nbs_magu_district/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# drop geom_local and subset as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE tz_2022_nbs_magu_district DROP COLUMN IF EXISTS geom_local;
DELETE FROM tz_2022_nbs_magu_district
  WHERE NOT (reg_code = '19' AND dist_code = '02');
COMMIT;"
# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tz_2022_nbs_magu_district',
  'geom_local', 4326, 'multipolygon', 2
);
UPDATE tz_2022_nbs_magu_district
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4326)));
CREATE INDEX tz_2022_nbs_magu_district_geom_local_idx
  ON tz_2022_nbs_magu_district
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tz_2022_nbs_magu_district',
  'geom_local', 4326, 'multipolygon', 2
);
UPDATE tz_2022_nbs_magu_district
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4326)));
CREATE INDEX tz_2022_nbs_magu_district_geom_local_idx
  ON tz_2022_nbs_magu_district
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
