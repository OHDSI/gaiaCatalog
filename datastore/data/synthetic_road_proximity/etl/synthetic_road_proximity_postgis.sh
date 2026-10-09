#!/bin/bash

# synthetic_road_proximity_postgis.sh
# Distance bands around the primary and secondary roads of us_2019_prisecroads_tl, as non-overlapping polygons (in 100 km tiles of EPSG:5070,
# subdivided into small pieces), with the SIMULATED near-road increment  2 * exp(-d_mid / 150 m)  ug/m3 of each band (illustrative values).

psql -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -v ON_ERROR_STOP=1 -c "
DROP TABLE IF EXISTS synthetic_road_proximity;
CREATE TEMP TABLE roads5070 AS SELECT ST_Transform(geom, 5070) AS geom FROM us_2019_prisecroads_tl;
CREATE INDEX ON roads5070 USING gist (geom);
CREATE TEMP TABLE bands (k int, band text, lo int, hi int, road_increment numeric);
INSERT INTO bands VALUES (1, '0-50 m', 0, 50, 1.693), (2, '50-100 m', 50, 100, 1.213), (3, '100-200 m', 100, 200, 0.736), (4, '200-400 m', 200, 400, 0.271);
CREATE TEMP TABLE tiles AS
  SELECT row_number() OVER () AS tid, g.geom FROM ST_SquareGrid(100000, (SELECT ST_SetSRID(ST_Extent(geom), 5070) FROM roads5070)) g
  WHERE EXISTS (SELECT 1 FROM roads5070 r WHERE r.geom && ST_Expand(g.geom, 400));
CREATE TEMP TABLE tile_buf AS
  SELECT t.tid, t.geom AS tile,
         ST_Buffer(c.g, 50, 'quad_segs=2') AS b1, ST_Buffer(c.g, 100, 'quad_segs=2') AS b2,
         ST_Buffer(c.g, 200, 'quad_segs=2') AS b3, ST_Buffer(c.g, 400, 'quad_segs=2') AS b4
  FROM tiles t
  JOIN LATERAL (SELECT ST_Collect(r.geom) AS g FROM roads5070 r WHERE r.geom && ST_Expand(t.geom, 400)) c ON true;
CREATE TABLE synthetic_road_proximity (
  ogc_fid serial PRIMARY KEY,
  geom geometry(MultiPolygon, 4269),
  band varchar,
  road_increment numeric,
  geom_local geometry(MultiPolygon, 4269));
INSERT INTO synthetic_road_proximity (geom, band, road_increment)
SELECT ST_Multi(ST_Transform(piece, 4269)), band, road_increment
FROM (
  SELECT bd.band, bd.road_increment,
         ST_Subdivide(ST_CollectionExtract(ST_MakeValid(ST_Intersection(
           CASE bd.k WHEN 1 THEN tb.b1 WHEN 2 THEN ST_Difference(tb.b2, tb.b1) WHEN 3 THEN ST_Difference(tb.b3, tb.b2) ELSE ST_Difference(tb.b4, tb.b3) END,
           tb.tile)), 3), 256) AS piece
  FROM tile_buf tb CROSS JOIN bands bd) x
WHERE NOT ST_IsEmpty(piece);
CREATE INDEX synthetic_road_proximity_geom_geom_idx ON synthetic_road_proximity USING gist (geom);
CREATE INDEX synthetic_road_proximity_geom_local_idx ON synthetic_road_proximity USING gist (geom_local);
NOTIFY pgrst, 'reload schema';
" 2>&1
