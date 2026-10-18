#!/bin/bash

# synthetic_county_ses_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/data/county_ses.csv
# Destination postGIS table: synthetic_county_ses

# give the data table and its relations a temporary name
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER SEQUENCE IF EXISTS synthetic_county_ses_ogc_fid_seq RENAME TO temp_ogc_fid_seq;
ALTER INDEX IF EXISTS synthetic_county_ses_geom_geom_idx RENAME TO temp_geom_idx;
ALTER TABLE IF EXISTS synthetic_county_ses RENAME CONSTRAINT synthetic_county_ses_pkey TO temp_pkey;
ALTER TABLE IF EXISTS synthetic_county_ses RENAME TO temp;
"

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2023_county_tl | sed 's/us_2023_county_tl/synthetic_county_ses/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# join as per custom parameters 
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
-- join temp to synthetic_county_ses (column)
ALTER TABLE synthetic_county_ses
  ADD COLUMN IF NOT EXISTS ses_index numeric;
UPDATE synthetic_county_ses 
SET
  ses_index = temp.ses_index::numeric
FROM temp
WHERE synthetic_county_ses.geoid = temp.geoid;


-- remove temporary table
DROP TABLE temp CASCADE;
"
