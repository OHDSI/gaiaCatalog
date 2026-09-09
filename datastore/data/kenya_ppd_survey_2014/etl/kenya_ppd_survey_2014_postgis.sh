#!/bin/bash

# kenya_ppd_survey_2014_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: local file
# Destination postGIS table: kenya_ppd_survey_2014
#
# Created by etl() on 2026-09-09 15:19:42
# Do not edit directly

# set credentials from postgres defaults and secret files
export POSTGRES_PASSWORD=$(cat $PG_PASSWORD_FILE)
export CDC_APP_TOKEN=$(cat $CDC_APP_TOKEN_FILE)
export AIRNOW_API_KEY=$(cat $AIRNOW_API_KEY_FILE)
export USGS_USER=$(cat $USGS_USER_FILE)
export USGS_PASSWORD=$(cat $USGS_PASSWORD_FILE)
export CENSUS_API_KEY=$(cat $CENSUS_API_KEY_FILE)


