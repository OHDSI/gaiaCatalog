#!/bin/bash

# hh_red_vial_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=%28nwr%5B%22highway%22~%22primary|secondary|tertiary|unclassified|residential|service|track%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%29;%28._;%3E;%29;out;
# Destination postGIS table: hh_red_vial_osm
#
# Created by etl() on 2026-10-17 21:44:54
# Do not edit directly

# Move into correct directory
cd /data/hh_red_vial_osm/


