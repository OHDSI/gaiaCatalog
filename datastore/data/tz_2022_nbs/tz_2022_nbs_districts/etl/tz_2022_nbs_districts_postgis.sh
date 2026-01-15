#!/bin/bash

# tz_2022_nbs_districts_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://microdata.nbs.go.tz/index.php/catalog/49/download/317
# Destination postGIS table: tz_2022_nbs_districts
#
# Created by etl() on 2025-10-05 15:59:41
# Do not edit directly

# remove duplicate points and make geometries valid:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
UPDATE tz_2022_nbs_districts
  SET geom=ST_MakeValid(ST_RemoveRepeatedPoints(geom));"

# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
SELECT AddGeometryColumn (
  'tz_2022_nbs_districts',
  'geom_local', 4326, 'multipolygon', 2
);
UPDATE tz_2022_nbs_districts
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),4326)));
CREATE INDEX tz_2022_nbs_districts_geom_local_idx
  ON tz_2022_nbs_districts
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
