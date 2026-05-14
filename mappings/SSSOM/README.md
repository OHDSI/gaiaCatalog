# SSSOM Mapping — Flat JSON to Schema.org JSON-LD

This directory contains an [SSSOM](https://mapping-commons.github.io/sssom/) (Simple Standard for Sharing Ontological Mappings) file that describes how a flat JSON dataset structure maps to [schema.org](https://schema.org/) terms, along with a Python script that uses those mappings to perform the actual transformation.

## Files

| File | Description |
|------|-------------|
| `test.sssom.tsv` | SSSOM mapping file defining the field-level correspondence between the source JSON and schema.org JSON-LD |
| `example_input.json` | Example source JSON file with two dataset records |
| `sssom_to_jsonld.py` | Python script that reads the SSSOM file and transforms the input JSON into a JSON-LD document |
| `example_output.jsonld` | JSON-LD output produced by running the script against the example input |

## The SSSOM File

`test.sssom.tsv` is a valid SSSOM TSV file. Its YAML metadata header (lines prefixed with `#`) declares:

- **`curie_map`** — prefix expansions for all CURIEs used in the file (`schema:`, `skos:`, `semapv:`, `owl:`, `myjson:`, `ext:`, `orcid:`)
- **`extension_definitions`** — two non-standard extension slots, `source_jsonpath` and `target_jsonpath`, declared under the `ext:` namespace and typed as `xsd:string`; these carry the JSONPath expressions the transform script uses
- **`mapping_set_id`**, **`mapping_set_title`**, **`license`**, **`creator_id`** — standard SSSOM provenance metadata

The mapping rows use:

- `skos:exactMatch` for fields with a direct semantic equivalent in schema.org
- `skos:closeMatch` for fields that are near-equivalent but require a structural or type transform (e.g. `keywords` is a JSON array; `publisher` is a plain string where schema.org expects an `Organization` object)
- `semapv:ManualMappingCuration` as the `mapping_justification` throughout
- `owl:Class` / `owl:ObjectProperty` as `subject_category` / `object_category` values

## How the Transform Works

`sssom_to_jsonld.py` drives the transformation entirely from the SSSOM file — no field names are hard-coded in the script.

1. **Parse the SSSOM file.** The `#`-prefixed header is loaded as YAML to extract the `curie_map` and other metadata; the remaining lines are read as TSV.
2. **Find the root mapping.** The single `owl:Class` row identifies the source JSONPath (`$.datasets[*]`) that locates the array of dataset objects and the target type (`schema:Dataset`).
3. **Iterate source items.** For each object matched by the root path, a new JSON-LD record is created with `@type: schema:Dataset`.
4. **Apply property mappings.** Each `owl:ObjectProperty` row carries a `source_jsonpath` (e.g. `$.datasets[*].title`) and a `target_jsonpath` (e.g. `$.name`). The script strips the root prefix from the source path to produce a relative path (`$.title`), evaluates it against the current item, and writes the result to the target property name.
5. **Output JSON-LD.** All records are written into a `@graph` array under a `@context` that sets `@vocab` to `https://schema.org/`, so unqualified property names resolve correctly without any additional context entries.

## Running the Script

### Prerequisites

```bash
pip install pyyaml jsonpath-ng ply
```

### Usage

```bash
python3 sssom_to_jsonld.py
```

The script expects `test.sssom.tsv` and `example_input.json` to be in the same directory and writes the result to `example_output.jsonld`.

### Expected output

```
Parsing test.sssom.tsv ...
  10 mapping row(s) loaded
Transforming example_input.json ...
  2 dataset record(s) mapped
Output written to example_output.jsonld
```

## Notes

- **`creator_id`** in `test.sssom.tsv` is set to a placeholder ORCID (`orcid:0000-0000-0000-0000`). Update this with a real ORCID before publishing the mapping set.
- The `publisher` field is carried through as a plain string. The SSSOM `comment` column for that row notes that schema.org expects an `Organization` or `Person` object — a structural transform would be needed for full compliance.
- The `keywords` field uses `skos:closeMatch` (confidence 0.9) because the source is a JSON array of strings while schema.org accepts either a comma-separated string or an array; the script passes the array through as-is.
