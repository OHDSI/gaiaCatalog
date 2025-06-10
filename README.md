# gaiaCatalog  

## Introduction  

gaiaCatalog contains all the materials to build the gaiaCatalog containers for use in the [OHDSI/GIS toolchain](https://github.com/OHDSI/GIS) as a part of the [Information on Observational Health Data Sciences and Informatics (OHDSI)](http://www.ohdsi.org/ "OHDSI Website") organization.  

**NOTE**: This is not a standalone tool. Plesae see the [gaiaDocker repository](https://github.com/OHDSI/gaiaDocker) for the integration into the [OHDSI/GIS toolchain](https://github.com/OHDSI/GIS).

This repository contains:  

- docker  
  The config files for the container builds  
  - repository: a simple flask app to provide a user interface  
  - solr: the solr index of the catalog entries  
- datastore  
	collection of catalog entries  
- examples  
	template files for the catalog entries  

### Dependencies  

- Linux, Mac, or Windows  
- Docker 1.27.0+  
- Git  

### Builds  

The build context for both images is the root directory of this repository ... or use the docker-compose on the dev branch of [gaiaDocker repository](https://github.com/OHDSI/gaiaDocker).

### Dockerhub

The images for the builds will be hosted on dockerhub.