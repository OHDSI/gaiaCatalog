#!/bin/bash

# mdc_2013_2022_avg_lst_30m_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13440658420002976&download=true
# Destination postGIS table: mdc_2013_2022_avg_lst_30m
#
# Created by etl() on 2026-10-10 21:07:58
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_2013_2022_lst_30m/mdc_2013_2022_avg_lst_30m/
mkdir -p derived


