#!/bin/bash

# hh_2023_bofedales_inaigem_postgis_derivative.sh
# Finish ETL into postGIS from postgis_derivative_postgis container
#
# Data source: https://datacochageoespacial.inaigem.gob.pe/geoserver/inventario_bofedales/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=inventario_bofedales%3Ainventario_bofedales_2023&outputFormat=application/json&bbox=-77.33,-10.7,-76.55,-9.8,EPSG:4326
# Destination postGIS table: hh_2023_bofedales_inaigem
#
# Created by etl() on 2026-10-17 21:41:48
# Do not edit directly

# Move into correct directory
cd /data/hh_2023_bofedales_inaigem/


