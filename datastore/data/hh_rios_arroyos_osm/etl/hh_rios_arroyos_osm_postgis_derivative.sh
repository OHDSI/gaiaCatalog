#!/bin/bash

# hh_rios_arroyos_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=nwr%5B%22waterway%22~%22river|stream%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%28._;>;%29;out;
# Destination postGIS table: hh_rios_arroyos_osm
#
# Created by etl() on 2026-10-17 21:43:13
# Do not edit directly

# Move into correct directory
cd /data/hh_rios_arroyos_osm/


