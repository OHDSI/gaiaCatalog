#!/bin/bash

# tz_populated_places_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=area%28id:3600195270%29-%3E.searchArea;node%5B%22place%22~%22city|town|village|hamlet%22%5D%28area.searchArea%29;%28._;%3E;%29;out;
# Destination postGIS table: tz_populated_places_osm
#
# Created by etl() on 2025-10-05 15:59:50
# Do not edit directly

# Move into correct directory
cd /data/tz_populated_places_osm/

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

