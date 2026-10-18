#!/bin/bash

# mdc_2013_2022_avg_lst_30m_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13440658420002976&download=true
# Destination postGIS table: mdc_2013_2022_avg_lst_30m
#
# Created by etl() on 2026-10-10 21:07:58
# Do not edit directly

# Move into correct directory
cd /data/mdc_2013_2022_lst_30m/mdc_2013_2022_avg_lst_30m/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_2013_2022_avg_lst_30m > derived/mdc_2013_2022_avg_lst_30m.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_2013_2022_avg_lst_30m.sql.tar.gz
tar -czf derived/mdc_2013_2022_avg_lst_30m.sql.tar.gz meta_dcat_mdc_2013_2022_avg_lst_30m.json -C derived mdc_2013_2022_avg_lst_30m.sql


