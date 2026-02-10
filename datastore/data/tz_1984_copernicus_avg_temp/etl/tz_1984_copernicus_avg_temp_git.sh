#!/bin/bash

# tz_1984_copernicus_avg_temp_git.sh
# Finish ETL into postGIS from git_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2026-02-10 13:37:47
# Do not edit directly

# create directory structure and move into it
mkdir -p /data/tz_1984_copernicus_avg_temp/download && mkdir -p /data/tz_1984_copernicus_avg_temp/etl && cd /data/tz_1984_copernicus_avg_temp

if [ -d "scripts" ]; then
  chmod 644 ./scripts/*
  git config --global --add safe.directory /data/tz_1984_copernicus_avg_temp/scripts
  cd scripts
  git pull origin main
  cd ..
else
  git clone https://github.com/tibbben/copernicus_aggregate.git scripts
fi
chmod 755 ./scripts/*

