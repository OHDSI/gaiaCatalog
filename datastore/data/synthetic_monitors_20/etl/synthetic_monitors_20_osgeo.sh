#!/bin/bash

# synthetic_monitors_20_osgeo.sh
# Download the monitors (WKT point and annual jsonb series) and load them into a raw table with ogr2ogr
#
# Data source: https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/monitors/data/monitors_20.csv

export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)

mkdir -p /data/synthetic_monitors_20/download -p /data/synthetic_monitors_20/etl
chmod -R 777 /data/synthetic_monitors_20
cd /data/synthetic_monitors_20

do_update=0
[[ -e datestamp ]] || do_update=1

if [[ $do_update = 1 ]]; then
  attempts=0
  until (
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 10 -O download/synthetic_monitors_20.csv 'https://raw.githubusercontent.com/OHDSI/GIS/main/syntheticDataGIS/monitors/data/monitors_20.csv' 2>&1
  ); do
    ((attempts++))
    if (( attempts > 3 )); then echo $?; break; fi
  done
  echo $(date '+%F %T') > datestamp
fi

ogr2ogr -f PostgreSQL PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" download/synthetic_monitors_20.csv -oo GEOM_POSSIBLE_NAMES=wkt -oo KEEP_GEOM_COLUMNS=NO -a_srs EPSG:4269 -nln synthetic_monitors_20_raw -lco GEOMETRY_NAME=geom -overwrite
echo success: synthetic_monitors_20.csv loaded with ogr2ogr
