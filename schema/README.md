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

## Files

- `gaia_catalog.yaml`: the schema.
- `generated/gaia_catalog.schema.json`: JSON Schema produced by
  `gen-json-schema schema/gaia_catalog.yaml`, for tools that do not use LinkML.
- `validation_report.md`: output of the last validation run.

## Notes on the model

- JSON-LD keywords are slots with an `alias`: `jsonld_id` is written `@id`,
  `jsonld_type` is `@type`.
- `type` (for example "Vector Dataset") is the catalog's own label, separate from
  the JSON-LD `@type`, which is always `Dataset`.
- The schema describes the flat form used today. The `@graph` form tried in
  commit `4589614` is not modelled; gaiaDB does not read it.
