#!/bin/bash

# synthetic_road_proximity_osgeo.sh
# Nothing is downloaded: the bands are derived from us_2019_prisecroads_tl in the postgis step.
mkdir -p /data/synthetic_road_proximity/download -p /data/synthetic_road_proximity/etl
chmod -R 777 /data/synthetic_road_proximity
echo success: synthetic_road_proximity is derived from us_2019_prisecroads_tl
