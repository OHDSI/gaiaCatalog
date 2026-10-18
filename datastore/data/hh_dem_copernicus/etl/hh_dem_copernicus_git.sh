#!/bin/bash

# hh_dem_copernicus_git.sh
# Finish ETL into postGIS from git_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: hh_dem_copernicus
#
# Created by etl() on 2026-10-17 21:45:06
# Do not edit directly

# create directory structure and move into it
mkdir -p /data/hh_dem_copernicus/download && mkdir -p /data/hh_dem_copernicus/etl && cd /data/hh_dem_copernicus

if [ -d "scripts" ]; then
  chmod 644 ./scripts/*
  git config --global --add safe.directory /data/hh_dem_copernicus/scripts
  cd scripts
  git pull origin main
  cd ..
else
  git clone https://github.com/tibbben/copernicus_aggregate.git scripts
fi
chmod 755 ./scripts/*

