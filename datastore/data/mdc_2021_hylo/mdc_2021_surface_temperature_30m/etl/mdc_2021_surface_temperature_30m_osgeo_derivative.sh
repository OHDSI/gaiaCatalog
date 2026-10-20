#!/bin/bash

# mdc_2021_surface_temperature_30m_osgeo_derivative.sh
# Finish ETL into postGIS from osgeo_derivative_postgis container
#
# Data source: https://scholarship.miami.edu/view/fileRedirect?instCode=01UOML_INST&filePid=13395678880002976&download=true
# Destination postGIS table: mdc_2021_surface_temperature_30m
#
# Created by etl() on 2026-10-20 10:44:57
# Do not edit directly

# Move into corrrect directory and create derivative directory in data package on osgeo
cd /data/mdc_2021_hylo/mdc_2021_surface_temperature_30m/
mkdir -p derived


