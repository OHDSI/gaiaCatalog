#!/bin/bash

# fl_2021_acs_5yr_tract_fsr_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://api.census.gov/data/2021/acs/acs5/
# Destination postGIS table: fl_2021_acs_5yr_tract_fsr
#
# Created by etl() on 2026-10-17 21:35:04
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t fl_2021_tl_tract | sed 's/fl_2021_tl_tract/fl_2021_acs_5yr_tract_fsr/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db

# join all variables to geom dependency
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
-- join total_population to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN total_population integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET total_population = st.agg
  FROM (
    SELECT geoid, (b01001_001e::integer) AS agg
    FROM total_population
    WHERE ABS(b01001_001e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.total_population IS 'b01001_001e';
DROP TABLE total_population;

-- join hispanic_population to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN hispanic_population integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET hispanic_population = st.agg
  FROM (
    SELECT geoid, (b01001i_001e::integer) AS agg
    FROM hispanic_population
    WHERE ABS(b01001i_001e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.hispanic_population IS 'b01001i_001e';
DROP TABLE hispanic_population;

-- join creole_speaking to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN creole_speaking int4;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET creole_speaking = st.agg
  FROM (
    SELECT geoid, (c16001_008e::int4) AS agg
    FROM creole_speaking
    WHERE ABS(c16001_008e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.creole_speaking IS 'c16001_008e';
DROP TABLE creole_speaking;

-- join latin_america_born to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN latin_america_born int4;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET latin_america_born = st.agg
  FROM (
    SELECT geoid, (b05007_048e::int4+b05007_045e::int4+b05007_051e::int4+b05007_042e::int4) AS agg
    FROM latin_america_born
    WHERE ABS(b05007_048e::numeric-(-666666666))>0.01 AND ABS(b05007_045e::numeric-(-666666666))>0.01 AND ABS(b05007_051e::numeric-(-666666666))>0.01 AND ABS(b05007_042e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.latin_america_born IS 'b05007_048e+b05007_045e+b05007_051e+b05007_042e';
DROP TABLE latin_america_born;

-- join persons_4_years_old_and_younger to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN persons_4_years_old_and_younger integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET persons_4_years_old_and_younger = st.agg
  FROM (
    SELECT geoid, (b01001_003e::integer+b01001_027e::integer) AS agg
    FROM persons_4_years_old_and_younger
    WHERE ABS(b01001_003e::numeric-(-666666666))>0.01 AND ABS(b01001_027e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.persons_4_years_old_and_younger IS 'b01001_003e+b01001_027e';
DROP TABLE persons_4_years_old_and_younger;

-- join age_of_5_and_19 to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN age_of_5_and_19 integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET age_of_5_and_19 = st.agg
  FROM (
    SELECT geoid, (b01001_004e::integer+b01001_005e::integer+b01001_006e::integer+b01001_007e::integer+b01001_028e::integer+b01001_029e::integer+b01001_030e::integer+b01001_031e::integer) AS agg
    FROM age_of_5_and_19
    WHERE ABS(b01001_004e::numeric-(-666666666))>0.01 AND ABS(b01001_005e::numeric-(-666666666))>0.01 AND ABS(b01001_006e::numeric-(-666666666))>0.01 AND ABS(b01001_007e::numeric-(-666666666))>0.01 AND ABS(b01001_028e::numeric-(-666666666))>0.01 AND ABS(b01001_029e::numeric-(-666666666))>0.01 AND ABS(b01001_030e::numeric-(-666666666))>0.01 AND ABS(b01001_031e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.age_of_5_and_19 IS 'b01001_004e+b01001_005e+b01001_006e+b01001_007e+b01001_028e+b01001_029e+b01001_030e+b01001_031e';
DROP TABLE age_of_5_and_19;

-- join persons_between_the_age_of_20_and_64 to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN persons_between_the_age_of_20_and_64 integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET persons_between_the_age_of_20_and_64 = st.agg
  FROM (
    SELECT geoid, (b01001_008e::integer+b01001_009e::integer+b01001_010e::integer+b01001_011e::integer+b01001_012e::integer+b01001_013e::integer+b01001_014e::integer+b01001_015e::integer+b01001_016e::integer+b01001_017e::integer+b01001_018e::integer+b01001_019e::integer+b01001_032e::integer+b01001_033e::integer+b01001_034e::integer+b01001_035e::integer+b01001_036e::integer+b01001_037e::integer+b01001_038e::integer+b01001_039e::integer+b01001_040e::integer+b01001_041e::integer+b01001_042e::integer+b01001_043e::integer) AS agg
    FROM persons_between_the_age_of_20_and_64
    WHERE ABS(b01001_008e::numeric-(-666666666))>0.01 AND ABS(b01001_009e::numeric-(-666666666))>0.01 AND ABS(b01001_010e::numeric-(-666666666))>0.01 AND ABS(b01001_011e::numeric-(-666666666))>0.01 AND ABS(b01001_012e::numeric-(-666666666))>0.01 AND ABS(b01001_013e::numeric-(-666666666))>0.01 AND ABS(b01001_014e::numeric-(-666666666))>0.01 AND ABS(b01001_015e::numeric-(-666666666))>0.01 AND ABS(b01001_016e::numeric-(-666666666))>0.01 AND ABS(b01001_017e::numeric-(-666666666))>0.01 AND ABS(b01001_018e::numeric-(-666666666))>0.01 AND ABS(b01001_019e::numeric-(-666666666))>0.01 AND ABS(b01001_032e::numeric-(-666666666))>0.01 AND ABS(b01001_033e::numeric-(-666666666))>0.01 AND ABS(b01001_034e::numeric-(-666666666))>0.01 AND ABS(b01001_035e::numeric-(-666666666))>0.01 AND ABS(b01001_036e::numeric-(-666666666))>0.01 AND ABS(b01001_037e::numeric-(-666666666))>0.01 AND ABS(b01001_038e::numeric-(-666666666))>0.01 AND ABS(b01001_039e::numeric-(-666666666))>0.01 AND ABS(b01001_040e::numeric-(-666666666))>0.01 AND ABS(b01001_041e::numeric-(-666666666))>0.01 AND ABS(b01001_042e::numeric-(-666666666))>0.01 AND ABS(b01001_043e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.persons_between_the_age_of_20_and_64 IS 'b01001_008e+b01001_009e+b01001_010e+b01001_011e+b01001_012e+b01001_013e+b01001_014e+b01001_015e+b01001_016e+b01001_017e+b01001_018e+b01001_019e+b01001_032e+b01001_033e+b01001_034e+b01001_035e+b01001_036e+b01001_037e+b01001_038e+b01001_039e+b01001_040e+b01001_041e+b01001_042e+b01001_043e';
DROP TABLE persons_between_the_age_of_20_and_64;

-- join persons_65_years_old_and_over to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN persons_65_years_old_and_over integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET persons_65_years_old_and_over = st.agg
  FROM (
    SELECT geoid, (b01001_020e::integer+b01001_021e::integer+b01001_022e::integer+b01001_023e::integer+b01001_024e::integer+b01001_025e::integer+b01001_044e::integer+b01001_045e::integer+b01001_046e::integer+b01001_047e::integer+b01001_048e::integer+b01001_049e::integer) AS agg
    FROM persons_65_years_old_and_over
    WHERE ABS(b01001_020e::numeric-(-666666666))>0.01 AND ABS(b01001_021e::numeric-(-666666666))>0.01 AND ABS(b01001_022e::numeric-(-666666666))>0.01 AND ABS(b01001_023e::numeric-(-666666666))>0.01 AND ABS(b01001_024e::numeric-(-666666666))>0.01 AND ABS(b01001_025e::numeric-(-666666666))>0.01 AND ABS(b01001_044e::numeric-(-666666666))>0.01 AND ABS(b01001_045e::numeric-(-666666666))>0.01 AND ABS(b01001_046e::numeric-(-666666666))>0.01 AND ABS(b01001_047e::numeric-(-666666666))>0.01 AND ABS(b01001_048e::numeric-(-666666666))>0.01 AND ABS(b01001_049e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.persons_65_years_old_and_over IS 'b01001_020e+b01001_021e+b01001_022e+b01001_023e+b01001_024e+b01001_025e+b01001_044e+b01001_045e+b01001_046e+b01001_047e+b01001_048e+b01001_049e';
DROP TABLE persons_65_years_old_and_over;

-- join born_in_haiti to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN born_in_haiti integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET born_in_haiti = st.agg
  FROM (
    SELECT geoid, (b05006_138e::integer) AS agg
    FROM born_in_haiti
    WHERE ABS(b05006_138e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.born_in_haiti IS 'b05006_138e';
DROP TABLE born_in_haiti;

-- join born_in_venezuela to fl_2021_acs_5yr_tract_fsr
ALTER TABLE fl_2021_acs_5yr_tract_fsr ADD COLUMN born_in_venezuela integer;
UPDATE fl_2021_acs_5yr_tract_fsr
  SET born_in_venezuela = st.agg
  FROM (
    SELECT geoid, (b05006_164e::integer) AS agg
    FROM born_in_venezuela
    WHERE ABS(b05006_164e::numeric-(-666666666))>0.01
  ) st
  WHERE fl_2021_acs_5yr_tract_fsr.geoid = st.geoid;
COMMENT ON COLUMN fl_2021_acs_5yr_tract_fsr.born_in_venezuela IS 'b05006_164e';
DROP TABLE born_in_venezuela;

DELETE FROM fl_2021_acs_5yr_tract_fsr WHERE total_population is Null;
"
# add local geometry column and reproject existing geometries into local EPSG:
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE fl_2021_acs_5yr_tract_fsr DROP COLUMN IF EXISTS geom_local CASCADE;
SELECT AddGeometryColumn (
  'fl_2021_acs_5yr_tract_fsr',
  'geom_local', 2236, 'multipolygon', 2
);
UPDATE fl_2021_acs_5yr_tract_fsr
  SET geom_local=ST_MakeValid(ST_RemoveRepeatedPoints(ST_Transform(ST_Multi(geom),2236)));
CREATE INDEX fl_2021_acs_5yr_tract_fsr_geom_local_idx
  ON fl_2021_acs_5yr_tract_fsr
  USING GIST (geom_local);
NOTIFY pgrst, 'reload schema';
"
