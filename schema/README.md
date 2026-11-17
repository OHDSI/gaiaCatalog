# Catalog schema

`gaia_catalog.yaml` is a [LinkML](https://linkml.io) schema for the flat schema.org
JSON-LD documents in `datastore/data/<id>/meta_json-ld_<id>.json`, the form that
gaiaDB ingests (`backbone.ingest_jsonld_metadata`). It replaces the draft table in
`shapeGraphs/requirements.md` as the statement of what a catalog entry must contain.

## Validate

```
python3 -m venv .venv-schema && .venv-schema/bin/pip install -r schema/requirements.txt
.venv-schema/bin/python architecture/defs/validate_catalog.py validate_catalog \
    --data_dir datastore/data --results_file catalog_validation.json \
    --report schema/validation_report.md
```

Use `--source <name>` (repeatable) to check selected entries and `--exit_zero` to
keep a zero exit status when there are errors.

Three layers of checks run on each document:

| Layer | What it checks | Where it lives |
|-------|----------------|----------------|
| schema | required slots, types, patterns, enums, unexpected keys | `gaia_catalog.yaml`, through LinkML's JSON Schema validator |
| recommended | recommended slots that are missing | `gaia_catalog.yaml` |
| semantic | rules across values (a vector needs a geometry term, no stray whitespace in names, year-like values in unit or min columns, ...) | `architecture/defs/validate_catalog.py` |

Severity: a missing `required` slot or a wrong value is an ERROR. A missing
`recommended` slot is a WARNING. A slot annotated `severity: warning` reports both its
absence and value problems (a malformed date, a missing `license`) as warnings.

## Two forms and the conversion

| | v1 (flat) | v2 (graph) |
|---|---|---|
| Schema | `gaia_catalog.yaml` | `gaia_catalog_v2.yaml` |
| Shape | one flat schema.org object | `{"@context", "@graph": [Dataset]}` |
| Read by gaiaDB | yes | no, convert first |

v2 is the form from commit `4589614`: creators carry roles, the place carries its
reference system and extent, the distribution is a `DataDownload`, and each
variable carries its reporting interval. It adds back what that commit dropped and
gaiaDB reads: `version`, `about`, and each variable's `minValue` and `maxValue`
(marked `origin: flat` in the schema).

```
# flat -> graph (add --etl to take update frequency and a few ETL settings from meta_etl)
python3 architecture/defs/convert_catalog.py convert_catalog --direction v1_to_v2 \
    --data_dir datastore/data --out_dir /tmp/v2
# graph -> flat
python3 architecture/defs/convert_catalog.py convert_catalog --direction v2_to_v1 \
    --data_dir /tmp/v2 --out_dir /tmp/v1
# check that flat -> graph -> flat gives back every entry
python3 architecture/defs/convert_catalog.py convert_catalog --direction check \
    --data_dir datastore/data
# validate graph documents
.venv-schema/bin/python architecture/defs/validate_catalog.py validate_catalog \
    --form v2 --data_dir /tmp/v2
```

- **Flat to graph keeps everything.** Going back gives the same document in a
  normal form: the context is the standard one, `distribution` is a list, the
  measurement terms use the standard descriptions, and `additionalProperty` is
  ordered with the EPSG entry first.
- **Graph to flat is lossy.** `funder`, `usageInfo`, `identifier`, the ETL settings
  in `additionalProperty`, the data-processing-level term and the variable source
  are dropped. A missing `version` is taken from the date of `dateModified`.
- The converter reads the single-object `provider` and `spatialCoverage` forms that
  `4589614` wrote, and writes lists.

## Files

- `gaia_catalog.yaml`, `gaia_catalog_v2.yaml`: the schemas.
- `generated/*.schema.json`: JSON Schemas produced by `gen-json-schema`, for tools that
  do not use LinkML.
- `validation_report.md`: output of the last validation run.

## Notes on the model

- JSON-LD keywords are slots with an `alias`: `jsonld_id` is written `@id`,
  `jsonld_type` is `@type`.
- `type` (for example "Vector Dataset") is the catalog's own label, separate from
  the JSON-LD `@type`, which is always `Dataset`.
- `gaia_catalog.yaml` describes the flat form used today; gaiaDB does not read the
  `@graph` form.
