#!/bin/bash

# us_2014_2019_monthly_pm25_by_county_cdc_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://data.cdc.gov/api/v3/views/53mz-4zqd/query.csv?query=SELECT%0A%20%20%60year%60%2C%0A%20%20%60date%60%2C%0A%20%20%60statefips%60%2C%0A%20%20%60countyfips%60%2C%0A%20%20%60pm25_max_pred%60%2C%0A%20%20%60pm25_med_pred%60%2C%0A%20%20%60pm25_mean_pred%60%2C%0A%20%20%60pm25_pop_pred%60%0AWHERE%0A%20%20caseless_one_of(%60year%60%2C%20%222014%22%2C%20%222015%22%2C%20%222016%22%2C%20%222017%22%2C%20%222018%22%2C%20%222019%22)&app_token='"$CDC_APP_TOKEN"'
# Destination postGIS table: us_2014_2019_monthly_pm25_by_county_cdc
#
# Created by etl() on 2026-09-09 15:19:57
# Do not edit directly

# give the data table and its relations a temporary name
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER SEQUENCE IF EXISTS us_2014_2019_monthly_pm25_by_county_cdc_ogc_fid_seq RENAME TO temp_ogc_fid_seq;
ALTER INDEX IF EXISTS us_2014_2019_monthly_pm25_by_county_cdc_geom_geom_idx RENAME TO temp_geom_idx;
ALTER TABLE IF EXISTS us_2014_2019_monthly_pm25_by_county_cdc RENAME CONSTRAINT us_2014_2019_monthly_pm25_by_county_cdc_pkey TO temp_pkey;
ALTER TABLE IF EXISTS us_2014_2019_monthly_pm25_by_county_cdc RENAME TO temp;
"

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2023_county_tl | sed 's/us_2023_county_tl/us_2014_2019_monthly_pm25_by_county_cdc/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# join as per custom parameters 
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
-- join temp to us_2014_2019_monthly_pm25_by_county_cdc (column)
ALTER TABLE us_2014_2019_monthly_pm25_by_county_cdc
  ADD COLUMN IF NOT EXISTS pm25_max_pred jsonb,
  ADD COLUMN IF NOT EXISTS pm25_med_pred jsonb,
  ADD COLUMN IF NOT EXISTS pm25_mean_pred jsonb,
  ADD COLUMN IF NOT EXISTS pm25_pop_pred jsonb;
SET LOCAL statement_timeout = '10min';
UPDATE us_2014_2019_monthly_pm25_by_county_cdc 
SET
  pm25_max_pred = temp.pm25_max_pred,
  pm25_med_pred = temp.pm25_med_pred,
  pm25_mean_pred = temp.pm25_mean_pred,
  pm25_pop_pred = temp.pm25_pop_pred
FROM temp
WHERE us_2014_2019_monthly_pm25_by_county_cdc.geoid = temp.geoid;

-- remove temporary table
DROP TABLE temp CASCADE;
"


