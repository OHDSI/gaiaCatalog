#!/bin/bash

# mdc_hospitals_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/Hospital_gdb/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json
# Destination postGIS table: mdc_hospitals
#
# Created by etl() on 2026-10-17 21:27:58
# Do not edit directly

# Move into correct directory
cd /data/mdc_hospitals/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_hospitals > derived/mdc_hospitals.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_hospitals.sql.tar.gz
tar -czf derived/mdc_hospitals.sql.tar.gz meta_dcat_mdc_hospitals.json -C derived mdc_hospitals.sql


