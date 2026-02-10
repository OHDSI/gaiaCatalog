#!/bin/bash

# tz_2022_nbs_districts_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://microdata.nbs.go.tz/index.php/catalog/49/download/317
# Destination postGIS table: tz_2022_nbs_districts
#
# Created by etl() on 2026-02-10 13:37:47
# Do not edit directly

# Move into correct directory
cd /data/tz_2022_nbs/tz_2022_nbs_districts/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

