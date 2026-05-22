# Kobo → Schema.org SSSOM Mapping Experiment

This directory contains an SSSOM mapping experiment that transforms a raw
[KoboToolbox](https://www.kobotoolbox.org/) metadata record into a richer
[Schema.org](https://schema.org/) JSON-LD document aligned with the Gaia
Catalog publication pattern.

## Files

| File | Description |
|------|-------------|
| `gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv` | SSSOM mapping file driving the transformation |
| `record_136_raw.json` | Raw KoboToolbox JSON export for record 136 (PM2.5 dataset) |
| `record_136_output.json` | Original transform output before the SSSOM update (kept for diff reference) |
| `record_136_output_v2.json` | Current transform output produced by the updated SSSOM and script |
| `pm25_vector_urban.json` | Target reference JSON-LD — the desired output shape |

The transform script lives one level up at `../sssom_to_jsonld.py`.

---

## Running the experiment

### Prerequisites

`sssom_to_jsonld.py` requires `pyyaml` and `jsonpath-ng`, both available in
the project's `pyproject.toml` dependency set. If running outside the project
environment:

```bash
pip install pyyaml jsonpath-ng ply
```

### Command

Run from the `mappings/SSSOM` directory:

```bash
cd /path/to/gaiaCatalog/mappings/SSSOM

python sssom_to_jsonld.py \
  --sssom  kobo/gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv \
  --input  kobo/record_136_raw.json \
  --output kobo/record_136_output_v2.json \
  --wrap-key datasets
```

The `--wrap-key datasets` flag is required because the raw Kobo export is a
single flat JSON object, but the SSSOM root path `$.datasets[*]` expects an
array. The flag wraps the record as `{"datasets": [<record>]}` before the
transform runs. When processing a multi-record Kobo export that is already a
list, omit the flag and the list is passed through as-is.

### Script CLI options

```
--sssom FILE      SSSOM TSV file (default: test.sssom.tsv in script directory)
--input FILE      Source JSON file (default: example_input.json in script directory)
--output FILE     Output JSON-LD file (default: example_output.jsonld in script directory)
--wrap-key KEY    Wrap a single flat record as {KEY: [record]} before transforming
```

### Comparing output to the reference

```bash
diff <(jq --sort-keys . kobo/record_136_output_v2.json) \
     <(jq --sort-keys . kobo/pm25_vector_urban.json)
```

Fields still absent from the SSSOM-derived output (require external data or
manual curation and cannot be auto-derived from the Kobo record):

| Field | Reason |
|---|---|
| `geo.box` inside `spatialCoverage` | Bounding box requires GIS computation |
| `hasPart` (workflow docs) | Not present in Kobo record |
| `about` (ETL Event) | Not present in Kobo record |
| `isBasedOn` | Not present in Kobo record |
| `subjectOf` | Not present in Kobo record |
| `variableMeasured[0]` VectorLocation anchor | Structural pattern with no Kobo source field |
| `minValue` / `maxValue` on attribute rows | Requires statistical scan of actual data |

---

## What changed in the SSSOM file

The mapping was updated to bring the transformer output closer to the
`pm25_vector_urban.json` reference. Changes fall into twelve areas.

### 1. Extended `@context` and new namespaces (header)

Four prefixes were added to `curie_map`:

| Prefix | URI |
|--------|-----|
| `qudt` | `http://qudt.org/schema/qudt/` |
| `unit` | `http://qudt.org/vocab/unit/` |
| `xsd` | `http://www.w3.org/2001/XMLSchema#` |
| `pato` | `http://purl.obolibrary.org/obo/PATO_` |

A new `context_language` extension slot was also declared so the transformer
emits `"@language": "en"` in the output `@context`.

### 2. Dataset-level `@id` and enriched context (`kobo:Dataset`)

`transform_rule` changed from `create_dataset_object` to
`create_dataset_object_with_id`.

The rule derives `@id` from `etl_group/table_name` using the pattern
`https://gdsc.idsc.miami.edu/detail/{table_name}` and injects `qudt`, `xsd`,
`pato`, `@language: en` into the output `@context`.

### 3. Identifier as structured PropertyValue (`kobo:doi`)

`transform_rule` changed from `doi_to_uri_or_string` to `doi_to_propertyvalue`.

Before: `"identifier": "10.7910/DVN/RHIFKL"`

After:
```json
"identifier": {
  "@type": "PropertyValue",
  "propertyID": "https://registry.identifiers.org/registry/doi",
  "value": "doi:10.7910/DVN/RHIFKL",
  "url": "https://doi.org/10.7910/DVN/RHIFKL"
}
```

### 4. License code resolved to full URI (`kobo:license`)

`transform_rule` changed to an explicit key=value lookup:

```
license_code_to_uri:cc_by=https://creativecommons.org/licenses/by/4.0/,
                   cc0=https://creativecommons.org/publicdomain/zero/1.0/,
                   cc_by_sa=https://creativecommons.org/licenses/by-sa/4.0/,
                   cc_by_nc=https://creativecommons.org/licenses/by-nc/4.0/
```

Before: `"license": "cc_by"` — After: `"license": "https://creativecommons.org/licenses/by/4.0/"`

### 5. Creator and publisher as typed objects

**`kobo:creator_name`** — `source_jsonpath` broadened to capture the full
creator sub-object; `transform_rule` changed from `organization_array` to
`role_organization_array`.

```json
"creator": [{"@type": "Role", "roleName": "creator",
             "creator": {"@type": "Organization", "name": "...", "description": "affiliation"}}]
```

**`kobo:publisher_name`** — remapped from `schema:publisher` to
`schema:provider`; `transform_rule` changed to `provider_organization_array`,
which resolves known institution names to their ROR identifiers
(e.g. "University of Miami GDSC" → `https://ror.org/02y3ad647`).

### 6. Spatial coverage as Place with GeoNames (`kobo:coverage_name`)

`source_jsonpath` broadened to the whole coverage sub-object;
`transform_rule` changed from `place_array` to `place_object_with_geonames`.

Builds a `Place` using `coverage_name` as `name` and constructs an
`additionalProperty` entry with the GeoNames URI derived from
`coverage_identifier` and `coverage_identifier_schema_uri`.

> **Note:** the bounding box (`geo.box`) in `pm25_vector_urban.json` cannot be
> derived from the Kobo record and must be merged in from an external GIS source.

### 7. `includedInDataCatalog` as DataCatalog objects (`kobo:collections`)

`transform_rule` changed from `split_space_to_array` to `datacatalog_objects`.

Each space-separated token becomes a typed `DataCatalog` at
`https://gdsc.idsc.miami.edu/?collection={token}`, with the root GDSC catalog
entry always prepended.

### 8. Structure and geometry as `measurementTechnique`

Both `kobo:structure` and `kobo:geometry` were remapped from
`schema:additionalProperty` to `schema:measurementTechnique` with
`definedterm:…` transform rules. Because both rows target the same property,
the transformer accumulates them into an array of two `DefinedTerm` objects.

| Subject | termSet | termSetUrl |
|---------|---------|------------|
| `kobo:structure` | `dataRepresentation` | `https://gdsc.idsc.miami.edu/vocab/dataRepresentation` |
| `kobo:geometry` | `vectorGeometry` | `https://gdsc.idsc.miami.edu/vocab/vectorGeometry` |

### 9. EPSG merged into `spatialCoverage.additionalProperty` (`kobo:epsg`)

Remapped from top-level `schema:additionalProperty` to
`$.spatialCoverage.additionalProperty` with transform rule:

```
srs_propertyvalue:uriTemplate=http://www.opengis.net/def/crs/EPSG/0/{value}
```

Appends a `PropertyValue` with `name=Spatial Reference System` and the full
OGC CRS URI as `value` to the Place's `additionalProperty` array.

### 10. Source URL as full DataDownload object (`kobo:source`)

`target_jsonpath` changed from `$.distribution[0].contentUrl` to
`$.distribution`; `transform_rule` changed to
`datadownload_source:type=DataDownload,name=Source distribution`.

The `extension_to_media_type_or_string` and `format_to_media_type_or_string`
rules then write `encodingFormat` into `$.distribution[0]`, resolving
file extensions and format codes to IANA media types (e.g. `shp` →
`application/x-shapefile`, `zip` → `application/zip`).

### 11. `variableMeasured` as proper Schema.org PropertyValue (`kobo:attributes`)

`transform_rule` changed from `attribute_objects` (which passed raw Kobo path
keys through unchanged) to `propertyvalue_schema_objects`.

| Kobo field | Schema.org target |
|---|---|
| `attribute_name` | `name` |
| `attribute_description` | `description` |
| `attribute_type` | `qudt:dataType` (`integer`→`xsd:integer`, `string`→`xsd:string`, `numeric`→`xsd:float`) |
| `attribute_unit` | `unitText` |
| `attribute_unit_concept_id` | `unitCode` |
| `attribute_concept_id` | `alternateName` |
| `attribute_start_date` + `attribute_end_date` | `additionalProperty[temporal_interval]` |

### 12. Two new mappings

**`kobo:temporalCoverage`** — derives an ISO 8601 interval string from the
minimum `attribute_start_date` and maximum `attribute_end_date` across all
attribute entries.

**`kobo:rights` → `schema:isAccessibleForFree`** — emits boolean `true` when
`dublin_core_group/rights` contains `creativecommons.org`.

---

## Transform rules implemented in `sssom_to_jsonld.py`

All rules introduced by the SSSOM update are implemented in `../sssom_to_jsonld.py`.
The script reads the `transform_rule` column from each mapping row and dispatches
to the matching handler via `apply_transform()`. A new `set_in_record()` function
handles writing values to nested target JSONPaths (e.g.
`$.spatialCoverage.additionalProperty`, `$.distribution[0].encodingFormat`).

| Rule | Behaviour |
|---|---|
| `create_dataset_object_with_id` | Sets `@id` from `etl_group/table_name`; injects qudt/xsd/pato/`@language` into `@context` |
| `doi_to_propertyvalue` | Returns a `PropertyValue` with `propertyID`, `doi:`-prefixed value, and `https://doi.org/` URL |
| `license_code_to_uri:k=v,…` | Parses inline key=value pairs; maps the input token to a URI; falls back to the raw value |
| `role_organization_array` | Wraps each source sub-object as `{"@type":"Role","roleName":"creator","creator":{"@type":"Organization",…}}` |
| `provider_organization_array` | Emits an `Organization`; resolves known names to ROR `@id` values |
| `place_object_with_geonames` | Builds a `Place` with `name` and GeoNames `additionalProperty` from the coverage sub-object |
| `datacatalog_objects` | Splits on space; maps each token to a `DataCatalog`; prepends the root GDSC catalog entry |
| `definedterm:termSet=…,termSetUrl=…,name=…` | Emits a `DefinedTerm` with `termCode` set to the raw value |
| `srs_propertyvalue:uriTemplate=…` | Emits a `PropertyValue` with the OGC CRS URI expanded from the template |
| `datadownload_source:type=…,name=…` | Emits a typed `DataDownload` object with `contentUrl` |
| `extension_to_media_type_or_string` | Maps file extensions to IANA media types; passes through unknown values |
| `format_to_media_type_or_string` | Maps format codes to IANA media types; passes through unknown values |
| `property_value:name=…` | Emits a `PropertyValue` with the given name and the raw value |
| `propertyvalue_schema_objects` | Maps each attribute sub-object to a full Schema.org `PropertyValue` |
| `date_range_from_attributes:start=…,end=…` | Scans all attribute items; returns `"{min}/{max}"` ISO 8601 interval |
| `cc_to_boolean` | Returns `true` if the value URL contains `creativecommons.org` |
| `string`, `date`, `array`, `controlled_value` | Pass-through; value is copied without modification |
