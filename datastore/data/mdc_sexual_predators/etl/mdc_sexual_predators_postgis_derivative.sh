#!/bin/bash

# mdc_sexual_predators_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/SEXPRED_gdb/FeatureServer/0/query?outFields=*&where=1%3D1&outSR=4326&f=geojson
# Destination postGIS table: mdc_sexual_predators
#
# Created by etl() on 2026-10-17 21:31:28
# Do not edit directly

# Move into correct directory
cd /data/mdc_sexual_predators/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_sexual_predators > derived/mdc_sexual_predators.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_sexual_predators.sql.tar.gz
tar -czf derived/mdc_sexual_predators.sql.tar.gz meta_dcat_mdc_sexual_predators.json -C derived mdc_sexual_predators.sql


