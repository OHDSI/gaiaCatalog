#!/bin/bash

# us_2014_2019_monthly_pm25_by_tract_cdc_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://data.cdc.gov/resource/qjxm-7fny.csv (2014-2015) and https://data.cdc.gov/resource/96sd-hxdt.csv (2016-2019)
# Destination postGIS table: us_2014_2019_monthly_pm25_by_tract_cdc

# give the data table and its relations a temporary name
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER SEQUENCE IF EXISTS us_2014_2019_monthly_pm25_by_tract_cdc_ogc_fid_seq RENAME TO temp_ogc_fid_seq;
ALTER INDEX IF EXISTS us_2014_2019_monthly_pm25_by_tract_cdc_geom_geom_idx RENAME TO temp_geom_idx;
ALTER TABLE IF EXISTS us_2014_2019_monthly_pm25_by_tract_cdc RENAME CONSTRAINT us_2014_2019_monthly_pm25_by_tract_cdc_pkey TO temp_pkey;
ALTER TABLE IF EXISTS us_2014_2019_monthly_pm25_by_tract_cdc RENAME TO temp;
"

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2019_tract_tl | sed 's/us_2019_tract_tl/us_2014_2019_monthly_pm25_by_tract_cdc/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db

# join as per custom parameters
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
-- join temp to us_2014_2019_monthly_pm25_by_tract_cdc (column)
ALTER TABLE us_2014_2019_monthly_pm25_by_tract_cdc
  ADD COLUMN IF NOT EXISTS pm25_mean_pred jsonb;
UPDATE us_2014_2019_monthly_pm25_by_tract_cdc
SET
  pm25_mean_pred = temp.pm25_mean_pred
FROM temp
WHERE us_2014_2019_monthly_pm25_by_tract_cdc.geoid = temp.geoid;


-- remove temporary table
DROP TABLE temp CASCADE;
"
