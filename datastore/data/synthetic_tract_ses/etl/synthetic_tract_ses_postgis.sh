#!/bin/bash

# synthetic_tract_ses_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/tract/data/tract_ses.csv
# Destination postGIS table: synthetic_tract_ses

# give the data table and its relations a temporary name
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
ALTER SEQUENCE IF EXISTS synthetic_tract_ses_ogc_fid_seq RENAME TO temp_ogc_fid_seq;
ALTER INDEX IF EXISTS synthetic_tract_ses_geom_geom_idx RENAME TO temp_geom_idx;
ALTER TABLE IF EXISTS synthetic_tract_ses RENAME CONSTRAINT synthetic_tract_ses_pkey TO temp_pkey;
ALTER TABLE IF EXISTS synthetic_tract_ses RENAME TO temp;
"

# Create copy of geom dependency
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2019_tract_tl | sed 's/us_2019_tract_tl/synthetic_tract_ses/g' | psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db 

# join as per custom parameters 
psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -c "
-- join temp to synthetic_tract_ses (column)
ALTER TABLE synthetic_tract_ses
  ADD COLUMN IF NOT EXISTS ses_index numeric;
UPDATE synthetic_tract_ses 
SET
  ses_index = temp.ses_index::numeric
FROM temp
WHERE synthetic_tract_ses.geoid = temp.geoid;


-- remove temporary table
DROP TABLE temp CASCADE;
"
