#!/bin/bash

# tz_1984_copernicus_avg_temp_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2025-10-05 15:59:40
# Do not edit directly

# Move into correct directory
cd /data/tz_1984_copernicus_avg_temp/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

