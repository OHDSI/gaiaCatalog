#!/bin/bash

# tz_1984_copernicus_avg_temp_gdsc.sh
# Finish ETL into postGIS from gdsc_postgis container
#
# Data source: https://github.com/tibbben/copernicus_aggregate.git
# Destination postGIS table: tz_1984_copernicus_avg_temp
#
# Created by etl() on 2025-08-26 12:54:48
# Do not edit directly

cd /data/tz_1984_copernicus_avg_temp/scripts
python copernicus_aggregate.py '{"table": "tz_1984_copernicus_avg_temp", "extension": "zip", "extent": ["29", "-12", "41", "-0.8"], "attributes": ["2m_temperature;Average yearly 2m temperature in Kelvin from Copernicus reanalysis era5 single levels;Copernicus;float;Kelvin;9523;287.315857;301.010986;1984-01-01;1984-12-31;35814756;2m_temperature@tz_1984_copernicus_avg_temp"], "bands": ["t2m"], "format": "nc"}' 1984

