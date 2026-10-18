#!/bin/bash

# mdc_federally_qualified_health_centers_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://services.arcgis.com/8Pc9XBTAsYuxx9Ny/arcgis/rest/services/FederallyQualifiedHealthCenter_gdb/FeatureServer/0/query?where=1%3D1&outFields=*&outSR=4326&f=json
# Destination postGIS table: mdc_federally_qualified_health_centers
#
# Created by etl() on 2026-10-17 21:28:13
# Do not edit directly

# Move into correct directory
cd /data/mdc_federally_qualified_health_centers/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t mdc_federally_qualified_health_centers > derived/mdc_federally_qualified_health_centers.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/mdc_federally_qualified_health_centers.sql.tar.gz
tar -czf derived/mdc_federally_qualified_health_centers.sql.tar.gz meta_dcat_mdc_federally_qualified_health_centers.json -C derived mdc_federally_qualified_health_centers.sql


