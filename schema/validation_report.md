# Catalog JSON-LD validation

121 sources checked against `gaia_catalog.yaml` on 2026-11-17 16:00 UTC: 3 pass, 61 with warnings only, 57 with errors.

## Issues by frequency

| Severity | Layer | Where | Issue | Sources | Count | Example |
|----------|-------|-------|-------|---------|-------|---------|
| ERROR | schema | `version` | value does not match pattern | 19 | 19 | synthetic_county_ses: '1' does not match '^\\d{4}-\\d{2}-\\d{2}$' |
| ERROR | schema | `variableMeasured[].qudt:dataType` | missing required slot | 18 | 77 | bogota_2019_estratos_manzana_dane: 'qudt:dataType' is a required property |
| ERROR | schema | `additionalProperty` | missing required slot | 12 | 12 | fl_2021_acs_5yr_tract_fsr: 'additionalProperty' is a required property |
| ERROR | semantic | `additionalProperty` | no spatial reference | 8 | 8 | fl_2021_acs_5yr_tract_fsr: a vector dataset needs a Spatial_reference_system property (EPSG code) |
| ERROR | schema | `datePublished` | missing required slot | 6 | 6 | fl_2022_tl_cousub: 'datePublished' is a required property |
| ERROR | schema | `variableMeasured[].maxValue` | value does not match pattern | 2 | 2 | mdc_county_park_boundaries: '2025-02-01' does not match '^-?\\d+(\\.\\d+)?([eE][-+]?\\d+)?$' |
| ERROR | schema | `url` | missing required slot | 1 | 1 | mdc_5000_addresses_normalized: 'url' is a required property |
| ERROR | semantic | `variableMeasured[].name` | duplicate variable | 1 | 10 | kenya_ppd_survey_2014: variable 'interview_id' appears 3 times |
| ERROR | semantic | `variableMeasured[].name` | name has stray whitespace | 1 | 3 | tz_2022_nbs_magu_district: variable name '\ndist_name' has leading or trailing whitespace |
| WARNING | recommended | `temporalCoverage` | recommended slot missing | 95 | 95 | bogota_2019_estratos_manzana_dane: temporalCoverage is recommended |
| WARNING | schema | `license` | missing required slot | 87 | 87 | egom_2012_viirs_vnp46a4: 'license' is a required property |
| WARNING | schema | `distribution` | wrong type | 71 | 71 | bogota_2019_estratos_manzana_dane: '/data/bogota_2019_estratos_manzana_dane/' is not of type 'array', 'null' |
| WARNING | recommended | `creator[].@type` | recommended slot missing | 45 | 69 | egom_2012_viirs_vnp46a4: @type is recommended |
| WARNING | recommended | `variableMeasured[].description` | recommended slot missing | 20 | 201 | bogota_2019_estratos_manzana_dane: description is recommended |
| WARNING | recommended | `includedInDataCatalog` | recommended slot missing | 18 | 18 | synthetic_county_ses: includedInDataCatalog is recommended |
| WARNING | semantic | `type` | type disagrees with structure | 7 | 7 | fl_2021_acs_5yr_tract_fsr: type is 'API' but dataRepresentation is vector |
| WARNING | recommended | `about` | recommended slot missing | 2 | 2 | synthetic_road_proximity: about is recommended |
| WARNING | schema | `variableMeasured[].endDate` | value does not match pattern | 2 | 236 | ma_2018_svi_tract: '12/31/18' does not match '^\\d{4}(-\\d{2}(-\\d{2})?)?$' |
| WARNING | schema | `variableMeasured[].startDate` | value does not match pattern | 2 | 236 | ma_2018_svi_tract: '1/1/18' does not match '^\\d{4}(-\\d{2}(-\\d{2})?)?$' |
| WARNING | schema | `dateModified` | value does not match pattern | 1 | 1 | kenya_ppd_survey_2014: 'not known' does not match '^\\d{4}-\\d{2}-\\d{2}([ T]\\d{2}:\\d{2}:\\d{2}Z?)?$' |
| WARNING | schema | `license` | value not in enum | 1 | 1 | fl_2019_tl_tract: "\n\nThe Software is provided to the User and those who may take by, through or under it, “as is,” without ... |
| WARNING | recommended | `type` | recommended slot missing | 1 | 1 | bogota_2019_estratos_manzana_dane: type is recommended |

## Sources

| Source | Status | Errors | Warnings |
|--------|--------|--------|----------|
| bogota_2019_estratos_manzana_dane | FAIL | 15 | 18 |
| hh_rios_ana | FAIL | 15 | 19 |
| hh_lagunas_ana | FAIL | 14 | 17 |
| kenya_ppd_survey_2014 | FAIL | 12 | 4 |
| hh_rios_arroyos_osm | FAIL | 8 | 10 |
| hh_glaciares_osm | FAIL | 4 | 6 |
| hh_red_vial_osm | FAIL | 4 | 6 |
| hh_rutas_pie_osm | FAIL | 4 | 6 |
| tz_2022_nbs_magu_district | FAIL | 3 | 2 |
| tz_populated_places_osm | FAIL | 3 | 2 |
| fl_2021_acs_5yr_tract_fsr | FAIL | 2 | 4 |
| mdc_2019_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_2020_2024_acs_5yr_trends_tract_dvmt | FAIL | 2 | 3 |
| mdc_2020_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_2021_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_2022_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_2023_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_2024_acs_5yr_tract_dvmt | FAIL | 2 | 3 |
| mdc_5000_addresses_normalized | FAIL | 2 | 5 |
| fl_2020_tl_tract | FAIL | 1 | 3 |
| fl_2021_tl_tract | FAIL | 1 | 3 |
| fl_2022_tl_cousub | FAIL | 1 | 21 |
| fl_2022_tl_tract | FAIL | 1 | 3 |
| fl_2023_tl_tract | FAIL | 1 | 3 |
| fl_2024_tl_tract | FAIL | 1 | 3 |
| fl_2025_tl_tract | FAIL | 1 | 3 |
| mdc_2021_nlcd_land_cover | FAIL | 1 | 3 |
| mdc_cooling_stations | FAIL | 1 | 14 |
| mdc_county_park_boundaries | FAIL | 1 | 3 |
| mdc_municipal_park_boundaries | FAIL | 1 | 3 |
| mdc_sexual_predators | FAIL | 1 | 3 |
| synthetic_county_ses | FAIL | 1 | 1 |
| synthetic_monitors_20 | FAIL | 1 | 1 |
| synthetic_monitors_200 | FAIL | 1 | 1 |
| synthetic_monitors_200_voronoi | FAIL | 1 | 1 |
| synthetic_monitors_20_voronoi | FAIL | 1 | 1 |
| synthetic_monitors_60 | FAIL | 1 | 1 |
| synthetic_monitors_60_voronoi | FAIL | 1 | 1 |
| synthetic_raster_annual | FAIL | 1 | 1 |
| synthetic_raster_landcover | FAIL | 1 | 1 |
| synthetic_raster_surface_100m | FAIL | 1 | 1 |
| synthetic_raster_surface_10km | FAIL | 1 | 1 |
| synthetic_raster_surface_1km | FAIL | 1 | 1 |
| synthetic_road_proximity | FAIL | 1 | 2 |
| synthetic_surface_100m | FAIL | 1 | 1 |
| synthetic_surface_10km | FAIL | 1 | 1 |
| synthetic_surface_1km | FAIL | 1 | 1 |
| synthetic_tract_ses | FAIL | 1 | 1 |
| us_2014_2019_monthly_pm25_by_tract_cdc | FAIL | 1 | 0 |
| us_2019_prisecroads_tl | FAIL | 1 | 2 |
| us_2019_tract_tl | FAIL | 1 | 3 |
| us_2020_census_county_fips | FAIL | 1 | 4 |
| us_2020_county_tl | FAIL | 1 | 20 |
| us_2022_annual_aqi_by_county | FAIL | 1 | 2 |
| us_2022_county_tl | FAIL | 1 | 20 |
| us_2023_annual_aqi_by_county | FAIL | 1 | 2 |
| us_nuclear_power_plants | FAIL | 1 | 4 |
| egom_2012_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2013_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2014_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2015_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2016_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2017_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2018_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2019_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2020_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2021_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2022_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2023_viirs_vnp46a4 | WARN | 0 | 5 |
| egom_2024_viirs_vnp46a4 | WARN | 0 | 5 |
| fl_2018_svi_tract | WARN | 0 | 3 |
| fl_2019_tl_tract | WARN | 0 | 3 |
| fl_2020_svi_county | WARN | 0 | 3 |
| fl_2020_svi_tract | WARN | 0 | 3 |
| fl_2022_svi_tract | WARN | 0 | 4 |
| fl_2026_flma | WARN | 0 | 3 |
| fl_superfund_waste_cleanup_sites | WARN | 0 | 12 |
| global_pm25_concentration_1998_2016 | WARN | 0 | 4 |
| hh_2023_bofedales_inaigem | WARN | 0 | 19 |
| hh_dem_srtm | WARN | 0 | 3 |
| ma_2018_svi_tract | WARN | 0 | 238 |
| ma_2020_svi_tract | WARN | 0 | 2 |
| ma_2022_svi_tract | WARN | 0 | 2 |
| mdc_2012_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2013_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2014_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2015_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2016_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2017_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2018_svi_tract | WARN | 0 | 3 |
| mdc_2018_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2019_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2020_svi_tract | WARN | 0 | 3 |
| mdc_2020_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2020_zcta | WARN | 0 | 3 |
| mdc_2021_nlcd_impervious_surfaces | WARN | 0 | 3 |
| mdc_2021_nlcd_tcc_v2023_5 | WARN | 0 | 3 |
| mdc_2021_nlcd_tcc_v4 | WARN | 0 | 3 |
| mdc_2022_svi_tract | WARN | 0 | 2 |
| mdc_2023_viirs_vnp46a4 | WARN | 0 | 5 |
| mdc_2026_flma | WARN | 0 | 4 |
| mdc_brownfield_site | WARN | 0 | 10 |
| mdc_community_health_centers | WARN | 0 | 2 |
| mdc_federally_qualified_health_centers | WARN | 0 | 2 |
| mdc_holc_redlining | WARN | 0 | 2 |
| mdc_hospitals | WARN | 0 | 2 |
| mdc_streets | WARN | 0 | 3 |
| mdc_water_polygons | WARN | 0 | 3 |
| tt_ferry_routes | WARN | 0 | 3 |
| tt_populated_places | WARN | 0 | 3 |
| tt_regions | WARN | 0 | 3 |
| tt_roads | WARN | 0 | 8 |
| tz_magu_dem_srtm | WARN | 0 | 3 |
| tz_regions_osm | WARN | 0 | 2 |
| us_2018_svi_county | WARN | 0 | 238 |
| us_2019_county_tl | WARN | 0 | 20 |
| us_2020_zcta | WARN | 0 | 3 |
| us_2023_county_tl | WARN | 0 | 20 |
| hh_dem_copernicus | PASS | 0 | 0 |
| tz_1984_copernicus_avg_temp | PASS | 0 | 0 |
| us_2014_2019_monthly_pm25_by_county_cdc | PASS | 0 | 0 |
