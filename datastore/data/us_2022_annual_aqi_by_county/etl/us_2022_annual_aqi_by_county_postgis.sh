#!/bin/bash

# us_2022_annual_aqi_by_county_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://aqs.epa.gov/aqsweb/airdata/annual_aqi_by_county_2022.zip
# Destination postGIS table: us_2022_annual_aqi_by_county
#
# Created by etl() on 2026-09-09 21:11:48
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)

# rename data table to temp
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER SEQUENCE IF EXISTS us_2022_annual_aqi_by_county_ogc_fid_seq RENAME TO temp_ogc_fid_seq;
ALTER INDEX IF EXISTS us_2022_annual_aqi_by_county_geom_geom_idx RENAME TO temp_geom_idx;
ALTER TABLE IF EXISTS us_2022_annual_aqi_by_county RENAME CONSTRAINT us_2022_annual_aqi_by_county_pkey TO temp_pkey;
ALTER TABLE us_2022_annual_aqi_by_county RENAME TO temp;"

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2022_county_tl | sed 's/us_2022_county_tl/us_2022_annual_aqi_by_county/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db

# join as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER TABLE temp ADD COLUMN geoid varchar;
UPDATE temp SET geoid = CONCAT(us_2020_census_county_fips.state,us_2020_census_county_fips.county)
  FROM us_2020_census_county_fips
  WHERE position(temp.state in us_2020_census_county_fips.state_name)>0
  AND position(temp.county in us_2020_census_county_fips.county_name)>0;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN state varchar;
UPDATE us_2022_annual_aqi_by_county SET state=temp.state::varchar
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN county varchar;
UPDATE us_2022_annual_aqi_by_county SET county=temp.county::varchar
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN year varchar;
UPDATE us_2022_annual_aqi_by_county SET year=temp.year::varchar
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_with_aqi int4;
UPDATE us_2022_annual_aqi_by_county SET days_with_aqi=temp.days_with_aqi::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN good_days int4;
UPDATE us_2022_annual_aqi_by_county SET good_days=temp.good_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN moderate_days int4;
UPDATE us_2022_annual_aqi_by_county SET moderate_days=temp.moderate_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN unhealthy_for_sensitive_groups_days int4;
UPDATE us_2022_annual_aqi_by_county SET unhealthy_for_sensitive_groups_days=temp.unhealthy_for_sensitive_groups_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN unhealthy_days int4;
UPDATE us_2022_annual_aqi_by_county SET unhealthy_days=temp.unhealthy_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN very_unhealthy_days int4;
UPDATE us_2022_annual_aqi_by_county SET very_unhealthy_days=temp.very_unhealthy_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN hazardous_days int4;
UPDATE us_2022_annual_aqi_by_county SET hazardous_days=temp.hazardous_days::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN max_aqi int4;
UPDATE us_2022_annual_aqi_by_county SET max_aqi=temp.max_aqi::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN n90th_percentile_aqi int4;
UPDATE us_2022_annual_aqi_by_county SET n90th_percentile_aqi=temp.n90th_percentile_aqi::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN median_aqi int4;
UPDATE us_2022_annual_aqi_by_county SET median_aqi=temp.median_aqi::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_co int4;
UPDATE us_2022_annual_aqi_by_county SET days_co=temp.days_co::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_no2 int4;
UPDATE us_2022_annual_aqi_by_county SET days_no2=temp.days_no2::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_ozone int4;
UPDATE us_2022_annual_aqi_by_county SET days_ozone=temp.days_ozone::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_pm25 int4;
UPDATE us_2022_annual_aqi_by_county SET days_pm25=temp.days_pm25::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

ALTER TABLE us_2022_annual_aqi_by_county ADD COLUMN days_pm10 int4;
UPDATE us_2022_annual_aqi_by_county SET days_pm10=temp.days_pm10::int4
  FROM temp
  WHERE us_2022_annual_aqi_by_county.geoid = temp.geoid;

DROP table temp;
"

