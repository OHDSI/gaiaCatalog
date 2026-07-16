# LLM Prompt — Generate a Reusable `kobo_testing.sssom.tsv` (record-number-agnostic)

> **Status: tested.** A mapping generated from these instructions was run through the real
> `sssom_to_jsonld.py` on records 136 (vector), 26 (vector), and 217 (raster). It produced
> valid JSON-LD on all three: `name`, `license`, `funder`, `identifier` populated;
> `creativeWorkStatus` = draft/published; `@type` = schema:Dataset (clean). No invented
> paths/IDs; placeholders suppressed; system fields documented via one skos:noMatch row.
>
> **Team decision baked in:** `collection_group/status` → `schema:creativeWorkStatus`
> (publication status), a change from the reviewed mapping's `measurementTechnique`.
> Doug to be informed by email.



Paste everything between the START/END markers into the LLM, then attach a SET of raw Kobo
records that together exercise the form (at minimum one vector + one raster; more is better).
The prompt is grounded in real Kobo field names and the transform rules that
`sssom_to_jsonld.py` actually implements, so the output will run — not just look right.

> Design principle: the mapping keys on FIELD NAMES and `$.datasets[*]`, never on record
> numbers. Any record of the same form — today's or a future one — flows through unchanged.

---

# ===== PROMPT START =====

You are an expert in SSSOM, Schema.org / Science-on-Schema.org, JSONPath, and KoboToolbox
metadata. Build ONE **reusable** SSSOM mapping file (TSV) that maps the KoboToolbox
authoring form to Schema.org JSON-LD, and works across ANY record of that form — vector or
raster — not one file per record.

## Inputs
A set of raw Kobo records is attached (sampled to cover both vector and raster dataset
types). Treat the UNION of their fields as the form schema. Do NOT tie any mapping to a
specific record number: the record identifiers are just samples. The mapping must cover any
field that appears in the form, and note where a field is specific to one dataset type so
one file serves all records.

## Output format — EXACTLY these 13 columns, tab-separated, in this order
```
subject_id	predicate_id	object_id	mapping_justification	confidence	subject_label	object_label	subject_category	object_category	source_jsonpath	target_jsonpath	transform_rule	comment
```
Precede the table with a YAML header of `#`-comment lines (curie_map, extension_definitions
for source_jsonpath/target_jsonpath/transform_rule, mapping_set_id, mapping_set_title,
mapping_set_description, license). Double-quote the title/description. The title/description
should describe the FORM (form-level, reusable), not any single record.

## Hard rules (do not violate)
1. `source_jsonpath` MUST start `$.datasets[*]` then the exact Kobo key in `['...']`.
   Add `[*]` when the key holds a list (a repeat group). Kobo keys contain slashes INSIDE
   the quotes, e.g. `$.datasets[*]['dublin_core_group/title']`.
   NEVER put a record number, record id, or index in a path. `$.datasets[*]` already means
   "every record". Paths reference FIELD NAMES only.
2. NEVER invent JSONPaths, Schema.org properties, ROR IDs, or GeoNames IDs. If unsure,
   use `skos:noMatch` or the skip path. "I don't know" is allowed.
3. First row MUST be the Dataset class:
   `kobo:Dataset  skos:exactMatch  schema:Dataset  semapv:ManualMappingCuration  1.0  Dataset  Dataset  owl:Class  owl:Class  $.datasets[*]  $  create_dataset_object_with_id  <comment>`
   Its @id must derive from a FIELD (`etl_group/table_name`), never from a record number.
4. `mapping_justification` is always `semapv:ManualMappingCuration`.
5. `confidence` is a decimal 0–1 (never a percentage). exactMatch→1.0, closeMatch→0.85–0.9,
   relatedMatch/uncertain→0.3–0.6.
6. Every row MUST have a non-empty `comment`, tagged with a strategy letter (A–G below).
7. Repeat groups (creator, publisher, sponsor, subject, coverage, attributes, band,
   file_name, no_data) map as ONE row each — the transform builds the object array; list
   sub-fields in the comment. Do NOT split a group into a row per sub-field.

## subject_category — MUST be owl:ObjectProperty (critical)
Set `subject_category` (and `object_category`) to `owl:ObjectProperty` for EVERY field row.
Use `owl:Class` ONLY for the first Dataset row. Do NOT use `owl:DatatypeProperty` or any other
value: the transformer processes only rows where `subject_category == owl:ObjectProperty`
(and the single `owl:Class` row), so any other category is SILENTLY SKIPPED and its field
never appears in the output.

## Return ONE file, not two
Output the `#`-prefixed YAML header and the TSV table TOGETHER in a single file: header lines
first, then a blank line, then the column-header row, then the data rows. Do NOT split the
header and table into separate files, and ensure a newline separates the last header line from
the column-header row.

## transform_rule — use ONLY these (they exist in sssom_to_jsonld.py)
Generic: `string`, `date`, `array`, `controlled_value`, `property_value`
Structural: `create_dataset_object_with_id`, `doi_to_propertyvalue`, `license_code_to_uri`,
`cc_to_boolean`, `role_organization_array`, `provider_organization_array`,
`sponsor_organization_array`, `place_object_with_geonames`, `datacatalog_objects`,
`definedterm`, `propertyvalue_schema_objects`, `date_range_from_attributes`,
`srs_propertyvalue`, `datadownload_source`, `extension_to_media_type_or_string`,
`format_to_media_type_or_string`
Control: `skip_if:values=--,TBD,not_applicable[;<chained_rule>]`
If a field needs a rule NOT in this list, set `transform_rule` to `PROPOSED_<name>` and
explain in the comment. Do NOT silently invent a working rule.
Parameterized syntax uses `rule:key=value,key=value`, e.g.
`license_code_to_uri:cc_by=https://creativecommons.org/licenses/by/4.0/,odc_by=https://opendatacommons.org/licenses/by/1.0/,cc0=https://creativecommons.org/publicdomain/zero/1.0/`.

## Strategy tags (put the letter first in each comment)
- **A** semantic match — `skos:exactMatch`/`closeMatch` to a real schema.org/DCT term
- **B** `additionalProperty` + `property_value` — operational metadata with no standard term
- **C** `definedterm` — controlled-vocabulary codes (resource_type, data_level, status, geometry)
- **D** nested sub-object transform — repeat groups (sponsor, file_name, no_data, band)
- **E** extend a composite rule — attribute sub-fields via `propertyvalue_schema_objects`
- **F** `skos:noMatch` — Kobo envelope/system fields intentionally excluded
- **G** `skip_if` — suppress placeholder values (`--`, `TBD`, `not_applicable`)

## Dataset-type conditionality (this is what makes ONE file reusable)
Detect dataset type from the FIELD `iso_group/structure` (values: `vector`, `raster`), not
from any record number. Some fields exist only for one type. Map them, but MARK the type in
the comment so one file serves all records:
- **VECTOR ONLY** (structure = vector): `iso_group/geometry`, `cartography_group/values_group`
- **RASTER ONLY** (structure = raster): `iso_group/band_group`, `iso_group/pixel_dimension`,
  `iso_group/dimension_units`
Prefix those comments with `VECTOR ONLY.` or `RASTER ONLY.`. A record lacking the field
simply produces no output for that row (a harmless no-op) — which is exactly why one file
can serve both types.

## When your sample has only ONE dataset type (only vector OR only raster)
The mapping must stay reusable even if the records you were given are all the same type.
The form schema is the same regardless of which records happened to be collected.

- Still emit BOTH the vector-only and raster-only rows, using the known form field names
  (VECTOR ONLY: `iso_group/geometry`, `cartography_group/values_group`; RASTER ONLY:
  `iso_group/band_group`, `iso_group/pixel_dimension`, `iso_group/dimension_units`).
- These are STANDARD fields of the Kobo authoring form, not record-specific inventions, so
  including them is not "inventing" — they are part of the form even if absent from this
  sample. Rows for absent fields simply no-op at transform time (safe).
- For a field type you have NOT seen in any sample, DO NOT invent a target property beyond the
  known anchors above. If you are unsure of the exact sub-fields, keep the row minimal (map the
  group to its known target with the known transform) and note in the comment:
  "type not present in sample — verify sub-fields against a record of this type."
- NEVER drop the conditional rows just because the sample lacks that type. Dropping them is
  what makes a file non-reusable and forces a new file per type — the exact problem we are
  avoiding.

So: a sample of only-raster (or only-vector) records still yields a file that covers BOTH.
Do not revert to a per-record/per-type prompt.

## Kobo envelope/system fields → strategy F (skos:noMatch) — use ONE representative row
Document the system fields as intentional non-mappings with a SINGLE representative
`skos:noMatch` row (subject_id `kobo:_submission_meta`, source_jsonpath
`$.datasets[*]['_submission_time']`, object_id empty, target/rule empty). List all the
excluded fields in that row's comment. Do NOT write a separate noMatch row per field.
Fields to name in that comment:
`_uuid, __version__, _submission_time, _xform_id_string, _status, _tags, _notes,
_geolocation, _validation_status, _submitted_by, formhub/uuid, meta/instanceID, meta/rootUuid`.

TWO deliberate exceptions (map these, do NOT exclude):
- `_id` -> `schema:identifier` (rule: `property_value:name=external_id`) — Kobo record id is a
  useful identifier; map it, do not noMatch it.
- `_attachments` -> ONE `skos:noMatch` row with object_id `schema:distribution` noted but NOT
  emitted (comment: attachments are submission infrastructure; if media needed, map
  `etl_group/source` instead).

## Placeholder fields → strategy G (skip_if)
Fields that are often `--`/`TBD`/`not_applicable`: `iso_group/lineage,
iso_group/process_step, iso_group/processor, etl_group/bash_etl, etl_group/sql_transform,
etl_group/parameters, etl_group/podid, etl_group/checksum, etl_group/up,
dublin_core_group/relation_group (relation_title), cartography_group/values_group
(value_field), etl_group/index_fields_group`. Map with
`skip_if:values=--,TBD,not_applicable` so they vanish when placeholder, pass through when real.

## Anchor rows you MUST include (field-based, verified)
Use these core mappings (fill remaining columns per the rules):
- `title → schema:name` (string)
- `description → schema:description` (string)
- `creator_group → schema:creator` (role_organization_array)
- `publisher_group → schema:provider` (provider_organization_array)
- `sponsor_group → schema:funder` (sponsor_organization_array)
- `doi → schema:identifier` (doi_to_propertyvalue)  [present only when the field exists]
- `license → schema:license` (license_code_to_uri with cc_by, cc0, odc_by, cc_by_sa, cc_by_nc)
- `coverage_group → schema:spatialCoverage` (place_object_with_geonames)
- `subject_group → schema:keywords` (array)
- `attributes_group → schema:variableMeasured` (propertyvalue_schema_objects)
- `geometry → schema:measurementTechnique` (definedterm) — VECTOR ONLY
- `band_group → schema:measurementTechnique or additionalProperty` — RASTER ONLY
- `update_frequency → dct:accrualPeriodicity` (controlled_value)
- `publication_date → schema:datePublished` (date); `last_updated → schema:dateModified` (date)
- `time_period_start` / `time_period_end → schema:temporalCoverage` (date range)


## Curated field decisions (learned from human-reviewed mappings — use these exactly)
These target/rule choices were validated against a human-reviewed mapping. Prefer them over
guessing, and NEVER leave these as PROPOSED:

Semantic term choices (object_id):
- `dublin_core_group/provenance` -> `dct:provenance` (rule: string)
- `dublin_core_group/license_text` -> `schema:usageInfo` (rule: string)  [NOT schema:license]
- `dublin_core_group/restrictions` -> `schema:conditionsOfAccess` (rule: string)
- `dublin_core_group/relation_group` -> `schema:isRelatedTo` (rule: skip_if:values=--,TBD,not_applicable;array)
- `control_group/external_id_group` -> `schema:identifier` (rule: property_value:name=externalId)
- `collection_group/status` -> `schema:creativeWorkStatus` (rule: controlled_value, target `$.creativeWorkStatus`)  [publication status; NOT measurementTechnique — team decision, Doug to be informed]
- `dublin_core_group/resource_type` -> `schema:additionalType` (rule: string)  [controlled_value and string are functionally identical here with no vocab table; keep `string` for compatibility with the reviewed mapping]
- `iso_group/data_level` -> `schema:measurementTechnique` (rule: definedterm)  [richer than additionalProperty]
- `iso_group/structure` -> `schema:measurementTechnique` (rule: definedterm)  [richer than additionalProperty]
- `collection_group/analytic_epsg` -> `schema:additionalProperty` (rule: srs_propertyvalue)  [use the SRS rule, not a plain value]
- `cartography_group/label` -> `schema:additionalProperty` (rule: property_value:name=label)
- `cartography_group/values_group` -> `schema:additionalProperty` (rule: skip_if:values=--,TBD;property_value:name=values)

Anti-patterns to AVOID (seen in earlier drafts):
- Do NOT map `_submission_time` or any `_`-prefixed system field to `schema:Dataset` or any
  schema.org property. All Kobo envelope fields are strategy F (`skos:noMatch`).
- Do NOT map dataset `status` to `measurementTechnique` (it is a work status).
- Do NOT downgrade a coded field (`resource_type`, `status`, `data_level`, `structure`) to
  plain `string` — use `controlled_value` or `definedterm`.
- Do NOT leave the fields listed above as `REQUIRES_CURATOR_REVIEW`/`PROPOSED_*` — they have
  known good targets.


## propertyvalue_schema_objects — only for attribute groups (avoid empty entries)
Send a repeat group through `propertyvalue_schema_objects` ONLY if its items have
`attribute_name` / `attribute_description` sub-fields (i.e. `cartography_group/attributes_group`).
Groups whose items use OTHER sub-field names — `band_group` (band_name),
`etl_group/columns_group` (column_name), `etl_group/index_fields_group` (index_field),
`etl_group/file_name_group` (file_name_value) — must NOT use this rule: they would emit empty
PropertyValues (blank name/description). Map those to `schema:additionalProperty` via
`property_value:name=<something>` instead. Also avoid mapping more than one row to
`$.temporalCoverage` (raw start/end plus an attribute-derived range will stack into a list —
keep one canonical source, send the others to additionalProperty).

## Target-path consistency (avoid a silent bug)
`target_jsonpath` MUST correspond to the chosen `object_id`. If `object_id` is
`schema:creativeWorkStatus`, `target_jsonpath` must be `$.creativeWorkStatus` — never a
leftover like `$.measurementTechnique`. A mismatched target path silently writes nothing.

## End of output
After the TSV, list any `PROPOSED_<rule>` rows and any field routed to `skos:noMatch`, so a
curator can review. Do not claim the file is approved — it is an AI draft requiring human
curation. Every row must reference a REAL field name from the attached records; produce ONLY
the YAML header + TSV + the short PROPOSED/noMatch list.

# ===== PROMPT END =====

---

## Why this is record-number-agnostic
- Every path is `$.datasets[*]` + a FIELD NAME. No record id, number, or index appears
  anywhere in the mapping.
- Dataset-type branching keys on the FIELD `iso_group/structure`, not on which record it is.
- The @id derives from `etl_group/table_name` (a field), so new records self-identify.
- Result: a future `record_500_raw.json` (or any id) flows through the same file untouched.

## After the LLM returns the file — verify with GLOB, not hard-coded numbers

Stage 1 — well-formedness (mapping only):
```bash
python vanilla_sssom.py --sssom sssom/kobo_testing.sssom.tsv
```

Stage 2 — transform EVERY record present, discovered by glob (no numbers listed):
```bash
for f in records/raw/record_*_raw.json; do
  rec=$(basename "$f" | sed 's/record_\(.*\)_raw.json/\1/')
  python scripts/sssom_to_jsonld.py \
    --sssom  sssom/kobo_testing.sssom.tsv \
    --input  "$f" \
    --output "records/outputs/record_${rec}_output.json" \
    --wrap-key datasets
  echo "record ${rec}: exit=$?"
done
```

Coverage check — for EACH record, list fields the mapping doesn't reference (catches new
fields a future record introduces), again with no hard-coded numbers:
```bash
python3 - <<'PY'
import json, glob, re, os
sssom = open("sssom/kobo_testing.sssom.tsv").read()
for f in sorted(glob.glob("records/raw/record_*_raw.json")):
    rec = re.search(r"record_(.+?)_raw", f).group(1)
    raw = json.load(open(f))
    missing = [k for k in raw if k.split('/')[-1] not in sssom and k not in sssom]
    print(f"record {rec}: {len(missing)} unmapped field(s)")
    for k in missing:
        print("   -", k)
PY
```
Any unmapped field is a candidate for a new row (or an intentional `skos:noMatch`). Then
hand-fix bad rows — this is an AI draft, not an approved file.
