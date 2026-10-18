#!/bin/bash

# mdc_2019_acs_5yr_tract_dvmt_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://api.census.gov/data/2019/acs/acs5/
# Destination postGIS table: mdc_2019_acs_5yr_tract_dvmt
#
# Created by etl() on 2026-10-17 21:02:17
# Do not edit directly

# Move into correct directory
cd /data/mdc_2019_acs_5yr_tract_dvmt/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_2019_acs_5yr_tract_dvmt > derived/mdc_2019_acs_5yr_tract_dvmt.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_2019_acs_5yr_tract_dvmt.sql.tar.gz
tar -czf derived/mdc_2019_acs_5yr_tract_dvmt.sql.tar.gz meta_dcat_mdc_2019_acs_5yr_tract_dvmt.json -C derived mdc_2019_acs_5yr_tract_dvmt.sql


