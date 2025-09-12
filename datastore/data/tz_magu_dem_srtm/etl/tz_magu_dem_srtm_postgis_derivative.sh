#!/bin/bash

# tz_magu_dem_srtm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11/
# Destination postGIS table: tz_magu_dem_srtm
#
# Created by etl() on 2025-09-11 18:03:33
# Do not edit directly

# Move into correct directory
cd /data/tz_magu_dem_srtm/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

