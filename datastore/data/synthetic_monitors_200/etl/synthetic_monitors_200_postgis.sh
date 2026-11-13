#!/bin/bash

# synthetic_monitors_200_postgis.sh
# Build the typed table of the monitors: point geometry, annual series as jsonb

psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -c "
DROP TABLE IF EXISTS synthetic_monitors_200;
CREATE TABLE synthetic_monitors_200 (
  ogc_fid serial PRIMARY KEY,
  geom geometry(Point, 4269),
  monitor_id integer,
  pm25_monitor jsonb,
  geom_local geometry(Point, 4269));
INSERT INTO synthetic_monitors_200 (geom, monitor_id, pm25_monitor, geom_local)
SELECT geom, monitor_id::integer, pm25_monitor::jsonb, geom
FROM synthetic_monitors_200_raw ORDER BY monitor_id::integer;
CREATE INDEX synthetic_monitors_200_geom_geom_idx ON synthetic_monitors_200 USING gist (geom);
DROP TABLE synthetic_monitors_200_raw;
"
