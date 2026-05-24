
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