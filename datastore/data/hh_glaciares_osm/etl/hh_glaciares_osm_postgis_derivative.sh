#!/bin/bash

# hh_glaciares_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=%28nwr%5B%22natural%22=%22glacier%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%29;%28._;%3E;%29;out;
# Destination postGIS table: hh_glaciares_osm
#
# Created by etl() on 2026-10-17 21:44:36
# Do not edit directly

# Move into correct directory
cd /data/hh_glaciares_osm/


