
## Draft requirements for metadata validation  


### top level descriptive metadata:

| field | requirement | notes |
| ----- | ----- | ----- | 
| { "@id": "string" | VIOLATION |  | 
| { "@type": "string" | VIOLATION |  | 
| { "name": "string" } | VIOLATION |  |
| { "version": YYYY-MM-DD } | VIOLATION |  |
| { "description": "string" } | VIOLATION |  |
| { "creator": { "name": "string" } } | VIOLATION | there will be more here (ORCID, ROR, etc) |
| { "provider": [ "string", ... ] } | VIOLATION | eventually this will look similar to creator (ROR) |
| { "license": "string" } | VIOLATION |  |  |
| { "spatialCoverage": { "name": "string" } } | VIOLATION | this will change |  
| { "datePublished": DATE } | VIOLATION |  |
| { "dateModified": DATE } | RECOMMENDED |  |
| { "keywords": [ "string", ... ] } | VIOLATION |  |
| { "url": "string" } | VIOLATION | landing page url, not source |
| { "about": [ { "name": "string" }, ... ] | RECOMMENDED | an attempt at provenance that will likely change 

### GIS ant ETL metadata

| field | requirement |  notes |
| ----- | ----- | ----- |
| { "measurementTechnique": [ { "termCode": "string" }, { "termCode": "string" } ] | VIOLATION | this will likely change. the first termCode can be one of: vector\|raster\|table; and the second termCode can be one of: point\|line\|polygon. Note that when first termCode is vector the second termCode is required, but the second termCode is not required for raster or table.
| { "additionalProperty": { "value": "string" } } | VIOLATION | EPSG code, this will likely change


### variable level metadata - from jsonld_data->'variableMeasured'

| field | requirement |  notes |
| ----- | ----- | ----- | 
| { "variableMeasured": [ { "propertyID": "string" }, ... ] } | RECOMMENDED | conceptID
| { "variableMeasured": [ { "name": "string" }, ... ] } | VIOLATION |  |
| { "variableMeasured": [ { "description": "string" }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "qudt:dataType" : "string" }, ... ] } | VIOLATION |  |
| { "variableMeasured": [ { "unitCode": "string" }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "unitText": "string" }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "minValue": numeric }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "maxValue": numeric }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "startDate": YYYY-MM-DD }, ... ] } | RECOMMENDED |  |
| { "variableMeasured": [ { "endDate": YYYY-MM-DD }, ... ] } | RECOMMENDED |  | 