#!/bin/bash

# tz_2022_nbs_magu_district_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: tz_2022_nbs_districts
# Destination postGIS table: tz_2022_nbs_magu_district
#
# Created by etl() on 2025-10-05 15:59:43
# Do not edit directly

# Move into correct directory
cd /data/tz_2022_nbs_magu_district/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

