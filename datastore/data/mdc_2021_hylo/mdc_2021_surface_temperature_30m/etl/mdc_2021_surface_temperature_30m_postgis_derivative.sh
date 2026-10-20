#!/bin/bash

# mdc_2021_surface_temperature_30m_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13395678880002976&download=true
# Destination postGIS table: mdc_2021_surface_temperature_30m
#
# Created by etl() on 2026-10-20 10:44:57
# Do not edit directly

# Move into correct directory
cd /data/mdc_2021_hylo/mdc_2021_surface_temperature_30m/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_2021_surface_temperature_30m > derived/mdc_2021_surface_temperature_30m.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_2021_surface_temperature_30m.sql.tar.gz
tar -czf derived/mdc_2021_surface_temperature_30m.sql.tar.gz meta_dcat_mdc_2021_surface_temperature_30m.json -C derived mdc_2021_surface_temperature_30m.sql


