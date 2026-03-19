#!/bin/bash

# kenya_ppd_survey_2014_postgis.sh
# Finish ETL into postGIS from postgis_postgis container
#
# Data source: local file
# Destination postGIS table: kenya_ppd_survey_2014
#
# Created by etl() on 2026-03-19 09:58:53
# Do not edit directly

export PGPASSWORD=$(cat $POSTGRES_PASSWORD_FILE)
export POSTGRES_PASSWORD=$(cat $POSTGRES_PASSWORD_FILE)

