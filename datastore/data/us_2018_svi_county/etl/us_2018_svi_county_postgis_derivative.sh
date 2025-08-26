#!/bin/bash

# us_2018_svi_county_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states_counties/SVI_2018_US_county.zip
# Destination postGIS table: us_2018_svi_county
#
# Created by etl() on 2025-08-26 12:54:48
# Do not edit directly

# Move into correct directory
cd /data/us_2018_svi_county/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2018_svi_county > derived/us_2018_svi_county.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/us_2018_svi_county.sql.tar.gz
tar -czf derived/us_2018_svi_county.sql.tar.gz meta_dcat_us_2018_svi_county.json -C derived us_2018_svi_county.sql


