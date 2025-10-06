#!/bin/bash

# tz_regions_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=rel%5B%22ISO3166-2%22~%22^TZ%22%5D%5Badmin_level=4%5D%5Btype=boundary%5D%5Bboundary=administrative%5D;(._;>;);out;
# Destination postGIS table: tz_regions_osm
#
# Created by etl() on 2025-10-05 15:59:50
# Do not edit directly

# Move into correct directory
cd /data/tz_regions_osm/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

