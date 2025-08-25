#!/bin/bash

# global_pm25_concentration_1998_2016_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://sedac.ciesin.columbia.edu/downloads/data/sdei/sdei-annual-pm2-5-concentrations-countries-urban-areas-v1-1998-2016/sdei-annual-pm2-5-concentrations-countries-urban-areas-v1-1998-2016-urban-areas-shp.zip
# Destination postGIS table: global_pm25_concentration_1998_2016
#
# Created by etl() on 2025-08-24 13:21:34
# Do not edit directly

# Move into correct directory
cd /data/global_pm25_concentration_1998_2016/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t global_pm25_concentration_1998_2016 > derived/global_pm25_concentration_1998_2016.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/global_pm25_concentration_1998_2016.sql.tar.gz
tar -czf derived/global_pm25_concentration_1998_2016.sql.tar.gz meta_dcat_global_pm25_concentration_1998_2016.json -C derived global_pm25_concentration_1998_2016.sql


