
# gaiaCatalog  

gaiaCatalog contains all the materials to build the gaiaCatalog containers for use in the [OHDSI/GIS toolchain](https://github.com/OHDSI/GIS) as a part of the [Information on Observational Health Data Sciences and Informatics (OHDSI)](http://www.ohdsi.org/ "OHDSI Website") organization. 

> **Status:** under active development

---

## Contents

- [Introduction](#introduction)
- [Dataset Structure](#dataset-structure)
- [Docker Container Builds](#docker-container-builds)
- [Support](#support)
- [Developer Guidelines](#developer-guidelines)

---

## Introduction

This repository has two principal components:

- a catalog comprised of metadata descriptions for GIS datasets
- two docker build specifications to provide a SOLR index of the catalog entries and a user interface to the index.

**NOTE**: This is not a standalone tool. Please see the [gaiaDB repository](https://github.com/OHDSI/gaiaDB) for integration into the gaiaDB project and the  [gaiaDocker repository](https://github.com/OHDSI/gaiaDocker) for the integration into a browser-based exploration and ingestion tool.

This repository contains:  

```
+-- datastore
    # metadata descriptions used by gaiaDB and gaiaDocker  
    +-- data
        # collection of catalog entries (see below for details)
    +-- collections
        # a description of the OHDSI data collection
+-- docker  
    # The config files for docker container builds used by gaiaDocker
    +-- repository 
        # a flask app to provide a user interface  
    +-- solr
        # the solr index of the catalog entries  
+-- examples  
    # template files for the catalog entries  
```

Note that there is more content under development.

### Dependencies  

- Linux, Mac, or Windows  
- Docker 1.27.0+  
- Git  

## Dataset Structure

Each dataset under `/datastore/data` follows this layout:

```
/datastore/data/{table_id}/
  meta_json-ld_{table_id}.json       ← JSON-LD metadata (dataset + variables)
  meta_etl_{table_id}.json           ← ETL configuration (geometry, EPSG, fields)
  meta_dcat_{table_id}.json          ← DCAT catalog metadata
  etl/
    {table_id}_osgeo.sh              ← Step 1: download + ogr2ogr load
    {table_id}_postgis.sh            ← Step 2: geometry cleanup + local projection
    {table_id}_osgeo_derivative.sh   ← (publishing) create derived osgeo outputs
    {table_id}_postgis_derivative.sh ← (publishing) pg_dump + tarball for download
  download/                          ← created at runtime by _osgeo.sh
  derived/                           ← created at runtime by derivative scripts
```


## Docker Container Builds  

The build context for both images is the root directory of this repository.

```shell
docker build -t gaia-catalog -f ./docker/repository/Dockerfile . 
docker build -t gaia-solr -f ./docker/solr/Dockerfile .
```

Or use the `docker compose` on the [gaiaDocker repository](https://github.com/OHDSI/gaiaDocker).

## Support

Please use the [GitHub issue tracker](https://github.com/OHDSI/gaiaCatalog/issues) for bugs and feature requests.

## Developer Guidelines

- Open an issue before starting significant work
- Create a feature branch and submit a Pull Request when ready
- PRs require review before merge to `main`
## Ingest status

A scheduled check ingests every source in `datastore/data` into a fresh
[gaiaDB](https://github.com/OHDSI/gaiaDB) container using
`backbone.ingest_datasource` and reports whether it succeeded. To run it locally
(requires Docker and the `ohdsi/gaia-db` image):

```
python architecture/masterControl.py validate_ingest --data_dir ./datastore/data \
    --results_file ./ingest_results.json --readme ./README.md
```

Use `--source <name>` (repeatable) to check selected sources only. The table
below is rewritten by that command; do not edit it by hand.

<!-- ingest-report:start -->
51 of 80 sources ingest into gaiaDB (fail: 17, timeout: 12, deferred, needs credentials or local data: 41, not ingestible: 3).

Last run: 2026-11-17 16:20 UTC using `ohdsi/gaia-db:main` sha256:03ac6ba13d19

| Source | Structure | Status | Failed step | Message | Warnings |
|--------|-----------|--------|-------------|---------|----------|
| hh_glaciares_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO hh_glaciares_osm FROM multipolygons; / ^ / ERROR: relation "hh_glaciares_osm" does not exist; small download... |  |
| hh_red_vial_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO hh_red_vial_osm FROM lines; / ^ / ERROR: relation "hh_red_vial_osm" does not exist; small download: <html> <... |  |
| hh_rios_arroyos_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO hh_rios_arroyos_osm FROM lines; / ^ / ERROR: relation "hh_rios_arroyos_osm" does not exist; small download: ... |  |
| hh_rutas_pie_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO hh_rutas_pie_osm FROM lines; / ^ / ERROR: relation "hh_rutas_pie_osm" does not exist; small download: <html>... |  |
| mdc_2021_nlcd_impervious_surfaces | raster | FAIL | dependency | dependency directory missing: us_2021_nlcd_impervious_surfaces |  |
| mdc_2021_nlcd_land_cover | raster | FAIL | dependency | dependency directory missing: us_2021_nlcd_land_cover |  |
| mdc_2021_nlcd_tcc_v2023_5 | raster | FAIL | dependency | dependency directory missing: us_2021_nlcd_tcc_v2023_5 |  |
| mdc_2021_nlcd_tcc_v4 | raster | FAIL | dependency | dependency directory missing: us_2021_nlcd_tcc_v4 |  |
| mdc_county_park_boundaries | vector | FAIL | metadata_load | Metadata load failed: invalid input syntax for type numeric: "2025-02-01" |  |
| mdc_municipal_park_boundaries | vector | FAIL | metadata_load | Metadata load failed: invalid input syntax for type numeric: "2018-06-01" |  |
| tt_ferry_routes | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tt_ferry_routes FROM lines; / ^ / ERROR: relation "tt_ferry_routes" does not exist; small download: <html> <... |  |
| tt_populated_places | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tt_populated_places FROM points; / ^ / ERROR: relation "tt_populated_places" does not exist; small download:... |  |
| tt_regions | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tt_regions FROM multipolygons; / ^ / ERROR: relation "tt_regions" does not exist; small download: <html> <he... |  |
| tt_roads | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tt_roads FROM lines; / ^ / ERROR: relation "tt_roads" does not exist; small download: <html> <head><title>40... |  |
| tz_2022_nbs_magu_district | vector | FAIL | dependency | dependency directory missing: tz_2022_nbs_districts |  |
| tz_populated_places_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tz_populated_places_osm FROM points; / ^ / ERROR: relation "tz_populated_places_osm" does not exist; small d... |  |
| tz_regions_osm | vector | FAIL | postgis | postgis script failed: script exited with status 1; script output: LINE 2: SELECT * INTO tz_regions_osm FROM multipolygons; / ^ / ERROR: relation "tz_regions_osm" does not exist; small download: <h... |  |
| bogota_2019_estratos_manzana_dane | vector | TIMEOUT | ingest | no result after 1800s |  |
| fl_2026_flma | vector | TIMEOUT | ingest | no result after 1800s |  |
| global_pm25_concentration_1998_2016 | vector | TIMEOUT | ingest | no result after 1800s |  |
| hh_2023_bofedales_inaigem | vector | TIMEOUT | ingest | no result after 1800s |  |
| hh_lagunas_ana | vector | TIMEOUT | ingest | no result after 1800s |  |
| hh_rios_ana | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_2026_flma | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_community_health_centers | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_holc_redlining | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_sexual_predators | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_streets | vector | TIMEOUT | ingest | no result after 1800s |  |
| mdc_water_polygons | vector | TIMEOUT | ingest | no result after 1800s |  |
| egom_2012_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2012_viirs_vnp46a4: data is supplied manually (no download step) and egom_2012_viirs_vnp46a4/download is not present |  |
| egom_2013_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2013_viirs_vnp46a4: data is supplied manually (no download step) and egom_2013_viirs_vnp46a4/download is not present |  |
| egom_2014_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2014_viirs_vnp46a4: data is supplied manually (no download step) and egom_2014_viirs_vnp46a4/download is not present |  |
| egom_2015_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2015_viirs_vnp46a4: data is supplied manually (no download step) and egom_2015_viirs_vnp46a4/download is not present |  |
| egom_2016_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2016_viirs_vnp46a4: data is supplied manually (no download step) and egom_2016_viirs_vnp46a4/download is not present |  |
| egom_2017_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2017_viirs_vnp46a4: data is supplied manually (no download step) and egom_2017_viirs_vnp46a4/download is not present |  |
| egom_2018_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2018_viirs_vnp46a4: data is supplied manually (no download step) and egom_2018_viirs_vnp46a4/download is not present |  |
| egom_2019_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2019_viirs_vnp46a4: data is supplied manually (no download step) and egom_2019_viirs_vnp46a4/download is not present |  |
| egom_2020_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2020_viirs_vnp46a4: data is supplied manually (no download step) and egom_2020_viirs_vnp46a4/download is not present |  |
| egom_2021_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2021_viirs_vnp46a4: data is supplied manually (no download step) and egom_2021_viirs_vnp46a4/download is not present |  |
| egom_2022_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2022_viirs_vnp46a4: data is supplied manually (no download step) and egom_2022_viirs_vnp46a4/download is not present |  |
| egom_2023_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2023_viirs_vnp46a4: data is supplied manually (no download step) and egom_2023_viirs_vnp46a4/download is not present |  |
| egom_2024_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2024_viirs_vnp46a4: data is supplied manually (no download step) and egom_2024_viirs_vnp46a4/download is not present |  |
| fl_2021_acs_5yr_tract_fsr | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| hh_dem_copernicus | raster | SKIPPED | deferred | deferred, test later: hh_dem_copernicus: data is supplied manually (no download step) and hh_dem_copernicus/download is not present |  |
| kenya_ppd_survey_2014 | table | SKIPPED | deferred | deferred, test later: kenya_ppd_survey_2014: data is supplied manually (no download step) and kenya_ppd_survey_2014/download is not present |  |
| mdc_2012_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2012_viirs_vnp46a4: data is supplied manually (no download step) and egom_2012_viirs_vnp46a4/download is not present |  |
| mdc_2013_2022_lst_30m |  | SKIPPED | metadata | no meta_etl_mdc_2013_2022_lst_30m.json; not an ingestible source |  |
| mdc_2013_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2013_viirs_vnp46a4: data is supplied manually (no download step) and egom_2013_viirs_vnp46a4/download is not present |  |
| mdc_2014_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2014_viirs_vnp46a4: data is supplied manually (no download step) and egom_2014_viirs_vnp46a4/download is not present |  |
| mdc_2015_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2015_viirs_vnp46a4: data is supplied manually (no download step) and egom_2015_viirs_vnp46a4/download is not present |  |
| mdc_2016_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2016_viirs_vnp46a4: data is supplied manually (no download step) and egom_2016_viirs_vnp46a4/download is not present |  |
| mdc_2017_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2017_viirs_vnp46a4: data is supplied manually (no download step) and egom_2017_viirs_vnp46a4/download is not present |  |
| mdc_2018_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2018_viirs_vnp46a4: data is supplied manually (no download step) and egom_2018_viirs_vnp46a4/download is not present |  |
| mdc_2019_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2019_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2019_viirs_vnp46a4: data is supplied manually (no download step) and egom_2019_viirs_vnp46a4/download is not present |  |
| mdc_2020_2024_acs_5yr_trends_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2020_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2020_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2020_viirs_vnp46a4: data is supplied manually (no download step) and egom_2020_viirs_vnp46a4/download is not present |  |
| mdc_2021_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2021_hylo |  | SKIPPED | metadata | no meta_etl_mdc_2021_hylo.json; not an ingestible source |  |
| mdc_2022_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2023_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_2023_viirs_vnp46a4 | raster | SKIPPED | deferred | deferred, test later: egom_2023_viirs_vnp46a4: data is supplied manually (no download step) and egom_2023_viirs_vnp46a4/download is not present |  |
| mdc_2024_acs_5yr_tract_dvmt | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| mdc_5000_addresses_normalized | vector | SKIPPED | deferred | deferred, test later: mdc_5000_addresses_normalized: data is supplied manually (no download step) and mdc_5000_addresses_normalized/download is not present |  |
| tz_1984_copernicus_avg_temp | raster | SKIPPED | deferred | deferred, test later: tz_1984_copernicus_avg_temp: data is supplied manually (no download step) and tz_1984_copernicus_avg_temp/download is not present |  |
| tz_2022_nbs |  | SKIPPED | metadata | no meta_etl_tz_2022_nbs.json; not an ingestible source |  |
| us_2014_2019_monthly_pm25_by_county_cdc | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CDC_APP_TOKEN) |  |
| us_2014_2019_monthly_pm25_by_tract_cdc | vector | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CDC_APP_TOKEN) |  |
| us_2020_census_county_fips | table | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| us_2022_annual_aqi_by_county | table | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| us_2023_annual_aqi_by_county | table | SKIPPED | deferred | deferred, test later: ETL scripts use credentials (CENSUS_API_KEY) |  |
| us_nuclear_power_plants | vector | SKIPPED | deferred | deferred, test later: us_nuclear_power_plants: ArcGIS endpoint now returns 'Token Required' (HTTP 200 with an error body) |  |
| fl_2018_svi_tract | vector | PASS |  |  | fields not in table: |
| fl_2019_tl_tract | vector | PASS |  |  |  |
| fl_2020_svi_county | vector | PASS |  |  |  |
| fl_2020_svi_tract | vector | PASS |  |  |  |
| fl_2020_tl_tract | vector | PASS |  |  |  |
| fl_2021_tl_tract | vector | PASS |  |  |  |
| fl_2022_svi_tract | vector | PASS |  |  |  |
| fl_2022_tl_cousub | vector | PASS |  |  |  |
| fl_2022_tl_tract | vector | PASS |  |  |  |
| fl_2023_tl_tract | vector | PASS |  |  |  |
| fl_2024_tl_tract | vector | PASS |  |  |  |
| fl_2025_tl_tract | vector | PASS |  |  |  |
| fl_superfund_waste_cleanup_sites | vector | PASS |  |  |  |
| hh_dem_srtm | raster | PASS |  |  |  |
| ma_2018_svi_tract | vector | PASS |  |  |  |
| ma_2020_svi_tract | vector | PASS |  |  |  |
| ma_2022_svi_tract | vector | PASS |  |  |  |
| mdc_2018_svi_tract | vector | PASS |  |  | fields not in table: |
| mdc_2020_svi_tract | vector | PASS |  |  |  |
| mdc_2020_zcta | vector | PASS |  |  |  |
| mdc_2022_svi_tract | vector | PASS |  |  |  |
| mdc_brownfield_site | vector | PASS |  |  |  |
| mdc_cooling_stations | vector | PASS |  |  |  |
| mdc_federally_qualified_health_centers | vector | PASS |  |  |  |
| mdc_hospitals | vector | PASS |  |  |  |
| synthetic_county_ses | vector | PASS |  |  |  |
| synthetic_monitors_20 | vector | PASS |  |  |  |
| synthetic_monitors_200 | vector | PASS |  |  |  |
| synthetic_monitors_200_voronoi | vector | PASS |  |  |  |
| synthetic_monitors_20_voronoi | vector | PASS |  |  |  |
| synthetic_monitors_60 | vector | PASS |  |  |  |
| synthetic_monitors_60_voronoi | vector | PASS |  |  |  |
| synthetic_raster_annual | raster | PASS |  |  |  |
| synthetic_raster_landcover | raster | PASS |  |  |  |
| synthetic_raster_surface_100m | raster | PASS |  |  |  |
| synthetic_raster_surface_10km | raster | PASS |  |  |  |
| synthetic_raster_surface_1km | raster | PASS |  |  |  |
| synthetic_road_proximity | vector | PASS |  |  |  |
| synthetic_surface_100m | vector | PASS |  |  |  |
| synthetic_surface_10km | vector | PASS |  |  |  |
| synthetic_surface_1km | vector | PASS |  |  |  |
| synthetic_tract_ses | vector | PASS |  |  |  |
| tz_magu_dem_srtm | raster | PASS |  |  |  |
| us_2018_svi_county | vector | PASS |  |  | fields not in table: , stcnty |
| us_2019_county_tl | vector | PASS |  |  |  |
| us_2019_prisecroads_tl | vector | PASS |  |  |  |
| us_2019_tract_tl | vector | PASS |  |  |  |
| us_2020_county_tl | vector | PASS |  |  |  |
| us_2020_zcta | vector | PASS |  |  |  |
| us_2022_county_tl | vector | PASS |  |  |  |
| us_2023_county_tl | vector | PASS |  |  |  |
<!-- ingest-report:end -->
