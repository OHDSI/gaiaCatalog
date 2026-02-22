# skills.md - ETL Skills for ma_2018_svi_tract

## Overview
Reusable agent skills for CDC SVI2018 Massachusetts tract data ETL:
1. Download/unzip FileGDB (.zip).
2. Load to PostGIS (`ma_2018_svi_tract`).
3. Clean geom, add local EPSG:26986 column/index.
4. Export SQL dump + tar w/ metadata.

**Run via Bash tool:** `workdir=&quot;$PWD&quot; command=&quot;./script.sh&quot;`
Requires: osgeo/postgis Docker containers, $POSTGRES_PASSWORD_FILE, gaia-db host.

## Prerequisites

### Environment Variables
All scripts expect the following env vars (set inside the Docker container):
| Variable | Description |
|----------|-------------|
| `POSTGRES_PASSWORD_FILE` | Path to file containing the DB password |
| `POSTGRES_DB` | Database name (e.g., `gaia`) |
| `POSTGRES_USER` | Database user |
| `POSTGRES_PORT` | Database port |

### Docker Context
Scripts run inside Docker containers (`osgeo/gdal` for download/load, `postgis` for SQL ops).
The PostGIS host is `gaia-db` (Docker network hostname).
Container-internal data path: `/data/ma_2018_svi_tract/`

### Setup (inside container)

## Skills

### 1. etl_download_load
**Script:** `./ma_2018_svi_tract_osgeo.sh`
**Container:** osgeo/gdal
**Desc:** Check datestamp ("Never" update frequency), wget the FileGDB zip from
`https://svi.cdc.gov/Documents/Data/2018/db/states/Massachusetts.zip`,
unzip, then `ogr2ogr` to PostGIS table `ma_2018_svi_tract` (multipolygon geom).
**Idempotent:** Yes (datestamp check; skips download if update_frequency is "Never" and datestamp exists).
**Note:** Both `wget` and `ogr2ogr` retry in an infinite loop until success.

### 2. etl_clean_geom
**Script:** `./ma_2018_svi_tract_postgis.sh`
**Container:** postgis
**Desc:** Cleans geometry with `ST_MakeValid(ST_RemoveRepeatedPoints(geom))`;
adds `geom_local` column reprojected to EPSG:26986; creates GIST index
`ma_2018_svi_tract_geom_local_idx`; issues `NOTIFY pgrst, 'reload schema'`.

### 3. etl_prepare_derived
**Script:** `./ma_2018_svi_tract_osgeo_derivative.sh`
**Container:** osgeo/gdal
**Desc:** Creates the `derived/` directory inside the data package. Sets `PGPASSWORD`.
This is a prep step that must run before the export derivative skill.

### 4. etl_export_derivative
**Script:** `./ma_2018_svi_tract_postgis_derivative.sh`
**Container:** postgis
**Desc:** `pg_dump -t ma_2018_svi_tract > derived/ma_2018_svi_tract.sql`;
then `tar -czf derived/ma_2018_svi_tract.sql.tar.gz meta_dcat_ma_2018_svi_tract.json -C derived ma_2018_svi_tract.sql`.
Packages the SQL dump with the DCAT metadata JSON.

### 5. full_etl_pipeline
**Sequence:**
1. `./ma_2018_svi_tract_osgeo_derivative.sh` (prep derived dir, runs on osgeo)
2. `./ma_2018_svi_tract_osgeo.sh` (download + load, runs on osgeo)
3. `./ma_2018_svi_tract_postgis.sh` (clean geom, runs on postgis)
4. `./ma_2018_svi_tract_postgis_derivative.sh` (export, runs on postgis)

## Verification

## Troubleshooting
- **Infinite retry:** `wget` and `ogr2ogr` in `ma_2018_svi_tract_osgeo.sh` loop until exit code 0. If the source URL is down, the script will hang. Kill and retry later.
- **Geom errors:** If `ST_MakeValid` fails, check source data integrity in the `download/` directory.
- **Schema isn’t reloaded:** Verify PostgREST received the `NOTIFY` or restart it manually.

## Notes
- `processStep/`: Pseudo-documentation of the ETL flow (empty placeholder).
- Generalize: Port to `architecture/masterControl.py etl_gdb` subcommand.
- Metadata: See `meta_dcat_ma_2018_svi_tract.json` and `meta_etl_ma_2018_svi_tract.json` in parent dir.
