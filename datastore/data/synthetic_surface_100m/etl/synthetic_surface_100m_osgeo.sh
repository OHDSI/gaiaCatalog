#!/bin/bash

# synthetic_surface_100m_osgeo.sh
# Download the random Fourier features of the surface and load them into postGIS (the grid is built in the postgis step)
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/tract/data/surface_100m_features.csv
# Destination postGIS table: synthetic_surface_100m_features (temporary)

export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)

mkdir -p /data/synthetic_surface_100m/download -p /data/synthetic_surface_100m/etl
chmod -R 777 /data/synthetic_surface_100m
cd /data/synthetic_surface_100m

do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  attempts=0
  until (
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_surface_100m.csv 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/tract/data/surface_100m_features.csv' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  echo $(date '+%F %T') > datestamp
fi

ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/synthetic_surface_100m.csv -dialect sqlite -sql "SELECT w1, w2, phase FROM synthetic_surface_100m" -lco COLUMN_TYPES="w1=varchar,w2=varchar,phase=varchar" -nlt NONE -nln synthetic_surface_100m_features
echo success: synthetic_surface_100m.csv loaded with ogr2ogr
