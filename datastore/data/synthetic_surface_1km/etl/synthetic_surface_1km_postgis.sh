#!/bin/bash

# synthetic_surface_1km_postgis.sh
# Build the grid of the synthetic surface in postGIS from the random Fourier features

psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -c "
DROP TABLE IF EXISTS synthetic_surface_1km;
CREATE TEMP TABLE cells AS
SELECT row_number() OVER () AS cell_id, g.geom AS geom5070, ST_X(ST_Centroid(g.geom)) AS cx, ST_Y(ST_Centroid(g.geom)) AS cy
FROM ST_SquareGrid(250, ST_Expand(ST_Transform(ST_SetSRID(ST_MakePoint(-118.25, 34.05), 4326), 5070), 5000)) g;
CREATE TEMP TABLE feat AS
  SELECT w1::double precision AS w1, w2::double precision AS w2, phase::double precision AS ph FROM synthetic_surface_1km_features;
CREATE TEMP TABLE cell_value AS
  SELECT c.cell_id, 9 + 1.9 * sqrt(2.0 / (SELECT count(*) FROM feat)) * sum(cos(f.w1 * c.cx + f.w2 * c.cy + f.ph)) AS v
  FROM cells c CROSS JOIN feat f GROUP BY c.cell_id;
CREATE TABLE synthetic_surface_1km (
  ogc_fid serial PRIMARY KEY,
  geom geometry(MultiPolygon, 4269),
  cell_id integer,
  pm25_surface numeric,
  geom_local geometry(MultiPolygon, 4269));
INSERT INTO synthetic_surface_1km (geom, cell_id, pm25_surface)
SELECT ST_Multi(ST_Transform(c.geom5070, 4269)), c.cell_id, v.v
FROM cells c JOIN cell_value v USING (cell_id);
CREATE INDEX synthetic_surface_1km_geom_geom_idx ON synthetic_surface_1km USING gist (geom);
DROP TABLE synthetic_surface_1km_features;
"
