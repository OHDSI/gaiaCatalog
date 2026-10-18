#!/bin/bash

# mdc_holc_redlining_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://services.arcgis.com/jIL9msH9OI208GCb/ArcGIS/rest/services/HOLC_Neighborhood_Redlining/FeatureServer/0/query?where=city=%27Miami%27&outFields=*&outSR=4326&f=json
# Destination postGIS table: mdc_holc_redlining
#
# Created by etl() on 2026-10-17 21:22:28
# Do not edit directly

# Move into correct directory
cd /data/mdc_holc_redlining/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_holc_redlining > derived/mdc_holc_redlining.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_holc_redlining.sql.tar.gz
tar -czf derived/mdc_holc_redlining.sql.tar.gz meta_dcat_mdc_holc_redlining.json -C derived mdc_holc_redlining.sql


