#!/bin/bash

# hh_rutas_pie_osm_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://overpass-api.de/api/interpreter?data=%28nwr%5B%22highway%22=%22path%22%5D%28-10.7,-77.33,-9.8,-76.55%29;nwr%5B%22highway%22=%22footway%22%5D%5B%22footway%22=%22trail%22%5D%28-10.7,-77.33,-9.8,-76.55%29;nwr%5B%22route%22=%22hiking%22%5D%28-10.7,-77.33,-9.8,-76.55%29;%29;%28._;>;%29;out;
# Destination postGIS table: hh_rutas_pie_osm
#
# Created by etl() on 2026-10-17 21:44:47
# Do not edit directly

# Move into correct directory
cd /data/hh_rutas_pie_osm/


