#!/bin/bash

# ma_2018_svi_tract_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip
# Destination postGIS table: ma_2018_svi_tract
#
# Created by etl() on 2025-09-07 17:36:04
# Do not edit directly

# Move into correct directory
cd /data/ma_2018_svi_tract/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t ma_2018_svi_tract > derived/ma_2018_svi_tract.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/ma_2018_svi_tract.sql.tar.gz
tar -czf derived/ma_2018_svi_tract.sql.tar.gz meta_dcat_ma_2018_svi_tract.json -C derived ma_2018_svi_tract.sql


