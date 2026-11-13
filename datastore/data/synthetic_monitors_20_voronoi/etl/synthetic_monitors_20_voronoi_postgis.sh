#!/bin/bash

# synthetic_monitors_20_voronoi_postgis.sh
# Voronoi (Thiessen) cells of the monitors in synthetic_monitors_20: every location of the window belongs to the cell of its nearest monitor.
# backbone.create_voronoi_source computes the cells in EPSG:5070 (metres), clips them to the 10 km study window and keeps the
# monitor's attributes (the series).

PGOPTIONS='-c client_min_messages=warning' psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -c "
SELECT backbone.create_voronoi_source('synthetic_monitors_20', 'synthetic_monitors_20_voronoi',
  ST_Expand(ST_Transform(ST_SetSRID(ST_MakePoint(-118.25, 34.05), 4326), 5070), 5000), 5070);
"
