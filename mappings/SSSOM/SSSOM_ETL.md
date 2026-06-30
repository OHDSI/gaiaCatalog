# Gaia SSSOM ETL Profile

This document explains how **executable SSSOM mapping files** in this directory
connect to `sssom_to_jsonld.py`: the extension columns (`source_jsonpath`,
`target_jsonpath`, `transform_rule`), the per-row ETL pipeline, every transform
rule used in `kobo/kobo_testing.sssom.tsv`, and where each rule is implemented
in code.

For Kobo-specific experiments and record-level results, see
`kobo/SSSOM_EXTRAS.md`. For running the Kobo experiment end-to-end, see
`kobo/README.md`.

---

## Two layers in one TSV file

Each mapping row carries two kinds of information:

| Layer | Columns | Consumed by |
|-------|---------|-------------|
| **Semantic (core SSSOM)** | `subject_id`, `predicate_id`, `object_id`, `mapping_justification`, `confidence`, labels, `comment` | Humans, `vanilla_sssom.py`, `sssom-py` validate/merge |
| **Operational (Gaia extensions)** | `source_jsonpath`, `target_jsonpath`, `transform_rule` | `sssom_to_jsonld.py` only |

Core SSSOM answers: *“Kobo `license` aligns to `schema:license` via
`skos:exactMatch`.”*

Extensions answer: *“Read
`$.datasets[*]['dublin_core_group/license']`, map `cc_by` → CC URI, write to
`$.license`.”*

The extensions are declared in the YAML metadata header under
`extension_definitions` (see `kobo/kobo_testing.sssom.tsv` lines 15–24).

---

## The three extension columns

| Column | Role | Example |
|--------|------|---------|
| `source_jsonpath` | **Where to read** in the input JSON | `$.datasets[*]['dublin_core_group/license']` |
| `target_jsonpath` | **Where to write** in the output JSON-LD node | `$.license` |
| `transform_rule` | **How to convert** the extracted value(s) | `license_code_to_uri:cc_by=https://…` |

**JSONPath lives in `source_jsonpath` and `target_jsonpath`.**  
**`transform_rule` is a separate mini-DSL** — named handlers and parameters
implemented in Python, not JSONPath expressions.

### Per-row pipeline

```
source_jsonpath  →  apply_transform(transform_rule)  →  set_in_record(target_jsonpath)
       ↓                         ↓                              ↓
  extract value(s)         reshape / filter              place in JSON-LD record
```

Example (`kobo:license`):

1. **Extract:** `"cc_by"` from the Kobo record
2. **Transform:** `"cc_by"` → `"https://creativecommons.org/licenses/by/4.0/"`
3. **Write:** result to `license` on the Dataset node

---

## End-to-end code flow

```
kobo_testing.sssom.tsv  +  record_136_raw.json
            │
            ▼
    parse_sssom()          ← sssom_to_jsonld.py
            │
            ▼
    transform()            ← one output record per $.datasets[*] item
            │
            ├── class row (owl:Class): set @type, optional @id rule
            │
            └── for each owl:ObjectProperty row:
                    relative_path()     strip root prefix from source_jsonpath
                    jp_parse().find()   extract value(s) from current item
                    apply_transform()   run transform_rule
                    set_in_record()     write to target_jsonpath
            │
            ▼
    { "@context": …, "@graph": [ … ] }
```

### Entry point

```bash
cd mappings/SSSOM

python sssom_to_jsonld.py \
  --sssom  kobo/kobo_testing.sssom.tsv \
  --input  kobo/record_136_raw.json \
  --output kobo/record_136_testing_output.json \
  --wrap-key datasets
```

`--wrap-key datasets` wraps a flat Kobo record as `{"datasets": [record]}`
because the root `source_jsonpath` is `$.datasets[*]`.

### Functions in `sssom_to_jsonld.py`

| Function | Lines (approx.) | Responsibility |
|----------|-----------------|----------------|
| `parse_sssom()` | 43–58 | Load `#` YAML metadata + TSV rows |
| `relative_path()` | 65–73 | Convert absolute source path to path relative to current dataset item |
| `transform()` | 492–548 | Orchestrate: find items, loop property rows, build `@graph` |
| `apply_transform()` | 236–485 | Dispatch `transform_rule` string to handler |
| `set_in_record()` | 76–158 | Write transformed value at `target_jsonpath` |
| `_parse_kv()` | 221–228 | Parse `k1=v1,k2=v2` suffixes on parameterized rules |
| `_flatten()` | 231–233 | Strip Kobo group prefixes from repeat-group dict keys |

### Root row vs property rows

**Class row** (`subject_category: owl:Class`) — typically one per file:

- `source_jsonpath`: `$.datasets[*]` — array of source records
- `target_jsonpath`: `$` — the whole output node
- `transform_rule`: `create_dataset_object_with_id` — sets `@id` from
  `etl_group/table_name` and expands `@context`

**Property rows** (`subject_category: owl:ObjectProperty`) — one per field mapping.

Rows with empty `source_jsonpath` / `target_jsonpath` / `transform_rule` (e.g.
`skos:noMatch` Kobo envelope fields) are skipped by the property loop.

### Relative JSONPath

Property `source_jsonpath` values are written absolute from the document root,
e.g. `$.datasets[*]['dublin_core_group/title']`. Inside the loop, `transform()`
already holds one dataset `item`, so `relative_path()` strips the root prefix:

```
$.datasets[*]['dublin_core_group/title']  →  $['dublin_core_group/title']
```

That relative path is evaluated against the current item via `jsonpath-ng`.

### Target JSONPath patterns (`set_in_record`)

| Pattern | Behaviour |
|---------|-----------|
| `$.name` | Set property; second write promotes to array |
| `$.additionalProperty[*]` | Always append to array |
| `$.spatialCoverage.additionalProperty` | Nested property on object |
| `$.distribution[0].encodingFormat` | Indexed array element + subproperty |
| `$['dct:provenance']` | Bracket notation for prefixed keys |

---

## Transform rule DSL

Rules are plain strings in the `transform_rule` column. Two syntax forms:

1. **Simple name** — `string`, `doi_to_propertyvalue`, `cc_to_boolean`
2. **Parameterized** — `name:param=value,…` — parameters parsed by `_parse_kv()`

Rules may be **chained** with `;` (left-to-right). Example:

```
skip_if:values=--,TBD,not_applicable;property_value:name=lineage
```

First segment filters placeholders; if value survives, second segment transforms.

If `apply_transform()` returns `None`, the row produces no output (field omitted).

---

## Transform rule catalog (`kobo_testing.sssom.tsv`)

52 of 54 rows carry a `transform_rule`. The two `skos:noMatch` rows
(`kobo:_submission_meta`, `kobo:_attachments`) intentionally leave extensions
empty.

### Pass-through

| Rule | Rows | Code | Effect |
|------|------|------|--------|
| `string` | 9 | `apply_transform()` ~279 | Copy value unchanged |
| `date` | 2 | same | Copy date string unchanged |
| `array` | 1 | same | Copy array unchanged |
| `controlled_value` | 1 | same | Copy vocabulary token unchanged |

### Lookup / template (parameters in TSV)

| Rule pattern | Example row | Code | Effect |
|--------------|-------------|------|--------|
| `license_code_to_uri:…` | `kobo:license` | ~292–296 | Map short code → URI; fallback to raw value |
| `definedterm:termSet=…,termSetUrl=…,name=…` | `kobo:structure` | ~374–387 | Emit `DefinedTerm` with `termCode` = source value |
| `property_value:name=…` | `kobo:table_name` | ~415–422 | Wrap in `PropertyValue` |
| `srs_propertyvalue:uriTemplate=…` | `kobo:epsg` | ~389–394 | EPSG code → OGC CRS URI in `PropertyValue` |
| `datadownload_source:type=…,name=…` | `kobo:source` | ~396–403 | Emit `DataDownload` with `contentUrl` |
| `date_range_from_attributes:start=…,end=…` | `kobo:temporalCoverage` | ~463–478 | Min start / max end across attribute group |

### Named handlers (logic in Python)

| Rule | Example row | Code | Effect |
|------|-------------|------|--------|
| `create_dataset_object_with_id` | `kobo:Dataset` | `transform()` ~510–513, context ~542–546 | `@id` from table name; `dct`/`qudt`/… in `@context` |
| `doi_to_propertyvalue` | `kobo:doi` | ~282–290 | Structured DOI `PropertyValue` |
| `role_organization_array` | `kobo:creator_name` | ~298–308 | Creator repeat → `Role` + `Organization` |
| `provider_organization_array` | `kobo:publisher_name` | ~310–320 | Publisher → `Organization` (+ `_ROR_LOOKUP`) |
| `sponsor_organization_array:…` | `kobo:sponsor` | ~322–341 | Sponsor repeat → `Organization` list on `funder` |
| `place_object_with_geonames` | `kobo:coverage_name` | ~343–363 | Coverage → `Place` + GeoNames `additionalProperty` |
| `datacatalog_objects` | `kobo:collections` | ~365–372 | Space-separated tokens → `DataCatalog` array |
| `propertyvalue_schema_objects` | `kobo:attributes` | ~424–461 | Attribute repeat → `variableMeasured` entries |
| `extension_to_media_type_or_string` | `kobo:extension` | ~405–408, `_EXTENSION_MEDIA_TYPES` | File extension → IANA type |
| `format_to_media_type_or_string` | `kobo:format` | ~410–413, `_FORMAT_MEDIA_TYPES` | Format code → IANA type |
| `cc_to_boolean` | `kobo:rights` | ~480–482 | `true` if value contains `creativecommons.org` |

### Chained (`skip_if` + transform)

| Rule pattern | Example row | Code | Effect |
|--------------|-------------|------|--------|
| `skip_if:values=…;string` | `kobo:relation_title` | ~260–276, chain ~248–258 | Drop `--` / `TBD` / `not_applicable`, else pass through |
| `skip_if:values=…;property_value:name=…` | `kobo:lineage` | same | Drop placeholders, else `PropertyValue` |

---

## Worked example: `kobo:license`

**SSSOM row (abbreviated):**

```
subject_id:     kobo:license
predicate_id:   skos:exactMatch
object_id:      schema:license
source_jsonpath:  $.datasets[*]['dublin_core_group/license']
target_jsonpath:  $.license
transform_rule:   license_code_to_uri:cc_by=https://creativecommons.org/licenses/by/4.0/,cc0=...
```

**In `transform()`** (property loop):

```python
rel = relative_path(src, root_src_path)       # $['dublin_core_group/license']
matches = jp_parse(rel).find(item)            # Match: "cc_by"
values = [m.value for m in matches]
transformed = apply_transform(rule, values) # "https://creativecommons.org/…"
set_in_record(record, "$.license", transformed)
```

**In `apply_transform()`:**

```python
if rule.startswith("license_code_to_uri"):
    params = _parse_kv(rule.split(":", 1)[1])  # {"cc_by": "https://…", …}
    raw = str(values[0]).strip()               # "cc_by"
    return params.get(raw, raw)                # URI or fallback
```

---

## Worked example: `kobo:attributes` (repeat group)

**source_jsonpath:** `$.datasets[*]['cartography_group/attributes_group'][*]`  
**target_jsonpath:** `$.variableMeasured`  
**transform_rule:** `propertyvalue_schema_objects`

The `[*]` on the source path collects **all** attribute sub-objects. The rule
receives a list of dicts, flattens Kobo keys via `_flatten()`, and returns a
list of schema.org `PropertyValue` objects. `set_in_record()` writes the list
to `variableMeasured` (first write sets; later writes to the same key would
promote to array — here one row supplies the full list).

Sub-field mapping inside the rule (not separate SSSOM rows):

| Kobo sub-field | Output property |
|----------------|---------------|
| `attribute_name` | `name` |
| `attribute_description` | `description` |
| `attribute_type` | `qudt:dataType` (via `_ATTR_TYPE_MAP`) |
| `attribute_unit` | `unitText` |
| `attribute_external_id` | nested `identifier` `PropertyValue` |
| `attribute_start_date` + `attribute_end_date` | `additionalProperty[temporal_interval]` |

---

## Mapping files in this directory

| File | Rows | Purpose |
|------|------|---------|
| `test.sssom.tsv` | 10 | Minimal tutorial mapping (flat JSON → schema.org) |
| `kobo/gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv` | 25 | Production Kobo mapping |
| `kobo/kobo_testing.sssom.tsv` | 54 | Production rows + experimental unmapped fields |

All three share the same extension profile and the same engine.

---

## Scripts: which tool when

| Script | Input | Output | Uses extensions? |
|--------|-------|--------|----------------|
| `sssom_to_jsonld.py` | SSSOM + JSON data | JSON-LD `@graph` | **Yes** |
| `vanilla_sssom.py` | SSSOM only | Summary / core TSV / JSON / Turtle | **No** |
| `sssom validate` (sssom-py) | SSSOM only | Validation report | Ignores extensions |

---

## Adding a new mapping

### 1. Simple field (pass-through)

If the Kobo value can be copied as-is:

```
kobo:my_field   skos:exactMatch   schema:myProp   …   \
  $.datasets[*]['some_group/my_field']   $.myProp   string   …
```

No Python change needed.

### 2. Parameterized existing rule

If an existing handler fits with different parameters (lookup table, name, URI
template), add a row with a new `transform_rule` suffix:

```
property_value:name=my_gaia_field
definedterm:termSet=myVocab,termSetUrl=https://…,name=My Label
skip_if:values=--,TBD;string
```

No Python change needed.

### 3. New structural behaviour

If the transform is novel (parse `ohdsi;5150` pairs, expand repeat groups
differently, etc.):

1. Add a branch in `apply_transform()` in `sssom_to_jsonld.py`
2. Add a row in the SSSOM file referencing the new rule name
3. Document the rule in this file (catalog table above)
4. Run:

```bash
python sssom_to_jsonld.py --sssom kobo/kobo_testing.sssom.tsv \
  --input kobo/record_136_raw.json \
  --output kobo/record_136_testing_output.json \
  --wrap-key datasets
```

### 4. Intentional non-mapping

Use `skos:noMatch`, leave extension columns empty, explain in `comment`
(see `kobo:_submission_meta`).

---

## Lookup tables in code (not in TSV)

Some rules use constants defined at the top of `sssom_to_jsonld.py`:

| Constant | Used by |
|----------|---------|
| `_ROR_LOOKUP` | `provider_organization_array` |
| `_GDSC_ROOT_CATALOG` | `datacatalog_objects` |
| `_EXTENSION_MEDIA_TYPES` | `extension_to_media_type_or_string` |
| `_FORMAT_MEDIA_TYPES` | `format_to_media_type_or_string` |
| `_ATTR_TYPE_MAP` | `propertyvalue_schema_objects` |

To change institution ROR IDs or media-type tables, edit these dicts in Python.
To change license code → URI mappings, edit the `transform_rule` cell in the TSV
(no Python change).

---

## Related reading

- `README.md` — quick start for `test.sssom.tsv` / `example_input.json`
- `kobo/README.md` — Kobo experiment commands and field notes
- `kobo/SSSOM_EXTRAS.md` — unmapped-field exploration and verification commands
- [SSSOM specification](https://mapping-commons.github.io/sssom/) — core format
  (extensions are spec-legal; execution is Gaia-specific)