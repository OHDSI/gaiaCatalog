#!/bin/bash

# us_2015_2019_monthly_pm25_by_county_cdc_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://data.cdc.gov/api/v3/views/53mz-4zqd/query.csv?query=SELECT%0A%20%20%60year%60%2C%0A%20%20%60date%60%2C%0A%20%20%60statefips%60%2C%0A%20%20%60countyfips%60%2C%0A%20%20%60pm25_max_pred%60%2C%0A%20%20%60pm25_med_pred%60%2C%0A%20%20%60pm25_mean_pred%60%2C%0A%20%20%60pm25_pop_pred%60%0AWHERE%0A%20%20caseless_one_of(%60year%60%2C%20%222014%22%2C%20%222015%22%2C%20%222016%22%2C%20%222017%22%2C%20%222018%22%2C%20%222019%22)&app_token='"$CDC_APP_TOKEN"'
# Destination postGIS table: us_2015_2019_monthly_pm25_by_county_cdc
#
# Created by etl() on 2026-09-06 12:36:52
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/us_2015_2019_monthly_pm25_by_county_cdc/
mkdir -p derived

# Create gpkg of table in derivate directory on osgeo 
rm -f derived/us_2015_2019_monthly_pm25_by_county_cdc.gpkg
ogr2ogr -f GPKG -overwrite derived/us_2015_2019_monthly_pm25_by_county_cdc.gpkg PG:"dbname=$POSTGRES_DB port=$POSTGRES_PORT user=$POSTGRES_USER password=$POSTGRES_PASSWORD host='gaia-db'" -select "state_fips,countyfips,geoid,pm25_max_pred,pm25_med_pred,pm25_mean_pred,pm25_pop_pred,geom" us_2015_2019_monthly_pm25_by_county_cdc

# Create downloadable tarfile of gpkg in derivative directory on osgeo
rm -f derived/us_2015_2019_monthly_pm25_by_county_cdc.gpkg.tar.gz
tar -czf derived/us_2015_2019_monthly_pm25_by_county_cdc.gpkg.tar.gz meta_dcat_us_2015_2019_monthly_pm25_by_county_cdc.json -C derived us_2015_2019_monthly_pm25_by_county_cdc.gpkg


