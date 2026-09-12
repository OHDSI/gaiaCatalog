#!/bin/bash

# us_2014_2019_monthly_pm25_by_county_cdc_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://data.cdc.gov/api/v3/views/53mz-4zqd/query.csv?query=SELECT%0A%20%20%60year%60%2C%0A%20%20%60date%60%2C%0A%20%20%60statefips%60%2C%0A%20%20%60countyfips%60%2C%0A%20%20%60pm25_max_pred%60%2C%0A%20%20%60pm25_med_pred%60%2C%0A%20%20%60pm25_mean_pred%60%2C%0A%20%20%60pm25_pop_pred%60%0AWHERE%0A%20%20caseless_one_of(%60year%60%2C%20%222014%22%2C%20%222015%22%2C%20%222016%22%2C%20%222017%22%2C%20%222018%22%2C%20%222019%22)&app_token='"$CDC_APP_TOKEN"'
# Destination postGIS table: us_2014_2019_monthly_pm25_by_county_cdc
#
# Created by etl() on 2026-09-11 21:43:19
# Do not edit directly

# Move into correct directory
cd /data/us_2014_2019_monthly_pm25_by_county_cdc/

# Create pg_dump of table SQL in derivate directory on postgis.
pg_dump -d $POSTGRES_DB -U $POSTGRES_USER -p $POSTGRES_PORT -h gaia-db -t us_2014_2019_monthly_pm25_by_county_cdc > derived/us_2014_2019_monthly_pm25_by_county_cdc.sql

# Create downloadable tarfile of SQL in derivative directory on postgis
rm -f derived/us_2014_2019_monthly_pm25_by_county_cdc.sql.tar.gz
tar -czf derived/us_2014_2019_monthly_pm25_by_county_cdc.sql.tar.gz meta_dcat_us_2014_2019_monthly_pm25_by_county_cdc.json -C derived us_2014_2019_monthly_pm25_by_county_cdc.sql


