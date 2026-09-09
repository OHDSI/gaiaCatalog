#!/bin/bash

# us_2020_census_county_fips_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: https://api.census.gov/data/2020/dec/dp?get=NAME&for=county:*
# Destination postGIS table: us_2020_census_county_fips
#
# Created by etl() on 2026-09-08 22:17:08
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)


