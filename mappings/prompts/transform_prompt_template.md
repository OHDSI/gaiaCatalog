# AI Prompt: Generate SSSOM TSV from KoboToolbox Raw JSON Export
**Location in repo:** `prompts/transform_prompt_template.md`  
**Purpose:** Ground an AI model fully before generating or extending the SSSOM TSV crosswalk file.  
**Use with:** Claude Sonnet or Opus — one record at a time.  
**Version:** v2 — revised after comparing AI output against Doug's reference file.

---

## How to Use This Prompt

1. Copy the full prompt below into Claude
2. Replace every `[PASTE ...]` block with the actual file contents
3. Specify in Step 3 whether you want a **full new SSSOM** or **extension rows only**
4. Review every output row against the Post-Generation Checklist before saving

> **First time creating this file?**
> Write `NONE — generating from scratch` in Step 2 and choose **Option A** in Step 3.
> You do NOT need to load a prior TSV file.

---

---

# PROMPT START

## Your Role

You are a metadata mapping specialist building an SSSOM (Simple Standard for Sharing
Ontological Mappings) TSV file that crosswalks a KoboToolbox raw JSON export to
Schema.org JSON-LD, following the GDSC (University of Miami Gaia Catalog) conventions.

Rules you must follow without exception:
- Only generate rows for fields that **actually exist** in the raw JSON below
- Never invent JSONPaths, Schema.org URIs, ROR identifiers, GeoNames IDs, or transform rules
- Never omit the `comment` column from any row
- Map at the **group level** for array groups — not field-by-field within an array item (see §4)
- Follow the `source_jsonpath` root pattern **exactly** as specified in §4

---

## Step 1 — Raw Kobo JSON (Source)

This is the raw, unedited export from KoboToolbox. It is the **only** source of truth
for what Kobo fields exist and what values they hold.

```json
[PASTE contents of record_NNN_raw.json here]
```

Before generating any rows, extract and list every leaf-level key path in the JSON.
Use Kobo slash-notation, including array wildcards. Example format:

- `dublin_core_group/title`
- `dublin_core_group/creator_group[*]/creator_name`
- `iso_group/structure`
- `cartography_group/attributes_group[*]/attribute_name`

Do not skip any field, even if the value is `"TBD"`, `"--"`, or null.
Mark TBD/-- fields immediately so you do not accidentally map them later.

---

## Step 2 — Existing SSSOM File (if extending)

If you are adding rows to an existing SSSOM, paste the full file here (including the
YAML header) so you do not duplicate mappings that already exist.

```tsv
[PASTE contents of existing .sssom.tsv here, including the full YAML header block]
```

Fields already mapped here **must not be repeated**.

If generating a fresh SSSOM from scratch, write: `NONE — generating from scratch`

---

## Step 3 — Task

[Choose one and delete the other]

**Option A — Generate full SSSOM from scratch:**
Generate a complete SSSOM TSV covering every mappable field from Step 1,
including the YAML header block.

**Option B — Extend existing SSSOM with new rows only:**
Generate only the new mapping rows (no header) for any Kobo fields in Step 1
not yet covered in Step 2.

---

## Step 4 — SSSOM Structure Rules

Every row you generate must follow these rules exactly.

### Required Columns (in this order)

```
subject_id | predicate_id | object_id | mapping_justification | confidence |
subject_label | object_label | subject_category | object_category |
source_jsonpath | target_jsonpath | transform_rule | comment
```

---

### Column Rules

| Column | Rule |
|---|---|
| `subject_id` | `kobo:{leafFieldName}` — leaf name only, **not** the full slash path. For group-level rows use a descriptive name e.g. `kobo:attributes`, `kobo:subject_terms` |
| `predicate_id` | One of: `skos:exactMatch`, `skos:closeMatch`, `skos:relatedMatch`, `skos:broadMatch` |
| `object_id` | A real, resolvable Schema.org, DCT, or DCAT CURIE — see §4a for mandatory decisions |
| `mapping_justification` | Always `semapv:ManualMappingCuration` |
| `confidence` | `1.0` for exactMatch · `0.85–0.9` for closeMatch · `0.7–0.8` for relatedMatch |
| `subject_label` | Short human-readable label for the Kobo field (sentence case, e.g. `Creator name`) |
| `object_label` | Schema.org property name only (e.g. `name`, `creator`, `spatialCoverage`) |
| `subject_category` | `owl:Class` for the top-level Dataset row only; `owl:ObjectProperty` for all other rows |
| `object_category` | Same logic as `subject_category` |
| `source_jsonpath` | See §4b — **must follow the exact root pattern** |
| `target_jsonpath` | Path in the output JSON-LD; see §4c for group-level patterns |
| `transform_rule` | From the known list in §4d — **always include parameters where required** |
| `comment` | One sentence: what the mapping does and any caveats or pipeline dependencies |

---

### §4a — Mandatory Schema.org Property Decisions

These decisions are fixed by the GDSC convention. Do not deviate from them.

| Kobo field | Correct `object_id` | Wrong — do not use |
|---|---|---|
| `dublin_core_group/title` | `schema:name` | `dct:title` |
| `dublin_core_group/creator_group[*]` (whole group) | `schema:creator` | `schema:name` |
| `dublin_core_group/publisher_group[*]` (whole group) | `schema:provider` | `schema:publisher`, `schema:name` |
| `dublin_core_group/coverage_group[*]` (whole group) | `schema:spatialCoverage` | `schema:name` |
| `dublin_core_group/rights` | `schema:isAccessibleForFree` | `schema:license` (that is handled by `kobo:license`) |
| `etl_group/source` | `schema:distribution` | `schema:contentUrl` (contentUrl is a child of distribution) |
| `iso_group/structure` | `schema:measurementTechnique` | `schema:additionalProperty` |
| `iso_group/geometry` | `schema:measurementTechnique` | `schema:additionalProperty` |
| `iso_group/epsg` | `schema:spatialCoverage` (as additionalProperty on the Place) | `schema:additionalProperty` (top-level) |
| `cartography_group/attributes_group[*]` (whole group) | `schema:variableMeasured` | map each sub-field separately |
| `dublin_core_group/subject_group[*]/subject_term` | `schema:keywords` | `schema:about` |
| `etl_group/update_frequency` | `dct:accrualPeriodicity` | `schema:additionalProperty` |

---

### §4b — `source_jsonpath` Root Pattern (CRITICAL)

**All `source_jsonpath` values must start with `$.datasets[*]`** because the pipeline
wraps records in a top-level `datasets` array using `--wrap-key datasets`.

| Field type | Pattern |
|---|---|
| Scalar field | `$.datasets[*]['group/field']` |
| Whole array group | `$.datasets[*]['group/array_group'][*]` |
| Leaf inside array | `$.datasets[*]['group/array_group'][*]['group/array_group/leaf']` |
| Nested leaf (keywords) | `$.datasets[*]['dublin_core_group/subject_group'][*]['dublin_core_group/subject_group/subject_term']` |

**Do not** write bare `$['group/field']` paths — they will break in the pipeline.

---

### §4c — Group-Level Mapping Strategy

For fields that come from **array groups** (creator, publisher, coverage, attributes, subject),
map the **whole group in a single row**, not one row per sub-field.

| Group | Single row approach | Example target_jsonpath |
|---|---|---|
| `creator_group[*]` | One row: `kobo:creator_name` → `schema:creator` with `role_organization_array` | `$.creator` |
| `publisher_group[*]` | One row: `kobo:publisher_name` → `schema:provider` with `provider_organization_array` | `$.provider` |
| `coverage_group[*]` | One row: `kobo:coverage_name` → `schema:spatialCoverage` with `place_object_with_geonames` | `$.spatialCoverage` |
| `attributes_group[*]` | One row: `kobo:attributes` → `schema:variableMeasured` with `propertyvalue_schema_objects` | `$.variableMeasured` |
| `subject_group[*]/subject_term` | One row: `kobo:subject_terms` → `schema:keywords` with `array` | `$.keywords` |

Put all sub-field handling instructions in the `comment` column of that single row.
Do **not** create separate rows for `attribute_name`, `attribute_description`, etc.

The **only exception** is `temporalCoverage`, which is a derived row from the
`attributes_group` dates and gets its own row with subject_id `kobo:temporalCoverage`.

---

### §4d — Transform Rules

Always use these exact names. Where the rule supports parameters, you **must** include them.

| Rule name | When to use | Required parameters |
|---|---|---|
| `string` | Direct string copy | none |
| `date` | ISO 8601 date value | none |
| `array` | Flat array of strings | none |
| `create_dataset_object_with_id` | Top-level Dataset row only | none; @id built from `etl_group/table_name` as `https://gdsc.idsc.miami.edu/detail/{table_name}` |
| `doi_to_propertyvalue` | DOI → PropertyValue with registry URI | none; emit `{"@type":"PropertyValue","propertyID":"https://registry.identifiers.org/registry/doi","value":"doi:{value}","url":"https://doi.org/{value}"}` |
| `license_code_to_uri` | Kobo code → CC URI | **Required:** `cc_by=https://creativecommons.org/licenses/by/4.0/,cc0=https://creativecommons.org/publicdomain/zero/1.0/,cc_by_sa=https://creativecommons.org/licenses/by-sa/4.0/,cc_by_nc=https://creativecommons.org/licenses/by-nc/4.0/` |
| `cc_to_boolean` | CC rights URI → `isAccessibleForFree` boolean | none; true if URI contains creativecommons.org or code is cc_by/cc0 |
| `role_organization_array` | creator_group → Role + Organization array | none; see comment column for sub-field mapping |
| `provider_organization_array` | publisher_group → Organization | none; resolve ROR for known institutions |
| `place_object_with_geonames` | coverage_group → Place object | none; include GeoNames additionalProperty from coverage_identifier |
| `datacatalog_objects` | Space-separated tokens → DataCatalog array | none; each token → `https://gdsc.idsc.miami.edu/?collection={token}` + root catalog |
| `definedterm` | Controlled vocab value → DefinedTerm | **Required:** `termSet={name},termSetUrl={url},name={label}` |
| `propertyvalue_schema_objects` | attributes_group → variableMeasured PropertyValue array | none; full sub-field mapping in comment |
| `date_range_from_attributes` | Derive temporalCoverage from attribute dates | **Required:** `start=attribute_start_date,end=attribute_end_date` |
| `srs_propertyvalue` | EPSG code → OGC SRS URI PropertyValue | **Required:** `uriTemplate=http://www.opengis.net/def/crs/EPSG/0/{value}` |
| `datadownload_source` | Source URL → DataDownload object | **Required:** `type=DataDownload,name=Source distribution` |
| `controlled_value` | Controlled vocab → known standard term | none; explain mapping in comment |
| `property_value` | Generic PropertyValue | **Required:** `name={propertyName}` e.g. `property_value:name=postgis_table` |
| `extension_to_media_type_or_string` | File extension → MIME type or fallback string | none; `zip`→`application/zip`, unknown→keep as string |
| `format_to_media_type_or_string` | Format code → MIME type or fallback string | none; `shp`→`application/x-esri-shapefile`, unknown→keep as string |

If none of the above rules fit, invent a new rule name using the pattern
`ruleName:param1=value1,param2=value2` and note it in the Validation Notes block.

---

### §4e — Mandatory Top-Level Row

The **first row** of every SSSOM must be the top-level Dataset row:

```
subject_id:        kobo:Dataset
predicate_id:      skos:exactMatch
object_id:         schema:Dataset
subject_category:  owl:Class
object_category:   owl:Class
source_jsonpath:   $.datasets[*]
target_jsonpath:   $
transform_rule:    create_dataset_object_with_id
comment:           Each Kobo submission becomes one Schema.org Dataset. Emit @id from etl_group/table_name as https://gdsc.idsc.miami.edu/detail/{table_name}. Extend @context with qudt, xsd, pato and set @language to en.
```

This row is required even when extending an existing SSSOM (skip only if it is already present).

---

## Step 5 — YAML Header Block (for Option A — full SSSOM only)

Place this above the column header row. Fill in the three `[FILL IN]` placeholders.

```yaml
# curie_map:
#   owl: http://www.w3.org/2002/07/owl#
#   schema: https://schema.org/
#   dct: http://purl.org/dc/terms/
#   dcat: http://www.w3.org/ns/dcat#
#   kobo: https://example.org/kobo/
#   gdsc: https://gdsc.idsc.miami.edu/terms/
#   skos: http://www.w3.org/2004/02/skos/core#
#   semapv: https://w3id.org/semapv/vocab/
#   ext: https://example.org/sssom-extensions/
#   qudt: http://qudt.org/schema/qudt/
#   unit: http://qudt.org/vocab/unit/
#   xsd: http://www.w3.org/2001/XMLSchema#
#   pato: http://purl.obolibrary.org/obo/PATO_
# extension_definitions:
#   - slot_name: source_jsonpath
#     property: ext:source_jsonpath
#     type_hint: http://www.w3.org/2001/XMLSchema#string
#   - slot_name: target_jsonpath
#     property: ext:target_jsonpath
#     type_hint: http://www.w3.org/2001/XMLSchema#string
#   - slot_name: transform_rule
#     property: ext:transform_rule
#     type_hint: http://www.w3.org/2001/XMLSchema#string
# mapping_set_id: https://example.org/mappings/[FILL IN — e.g. gaia_metadata_authoring_form_v2_record_217]
# mapping_set_title: "[FILL IN — always wrap in double quotes, e.g.: GDSC Gaia Catalog KoboToolbox Form v2 to Schema.org JSON-LD (Record 217: 1984 Tanzania 2m Temperature)]"
# mapping_set_description: "[FILL IN — always wrap in double quotes. A colon, semicolon, or parenthesis in an unquoted YAML value will crash the parser.]"
# license: https://creativecommons.org/publicdomain/zero/1.0/
```

> **⚠️ YAML string quoting rule — violations cause a hard crash in `parse_sssom`:**
> - `mapping_set_title` and `mapping_set_description` **must always be wrapped in double quotes**
> - Any value containing `: ` (colon-space), `;`, `(`, `)`, or `--` must be quoted
> - Never use tab characters on header lines — YAML forbids them
> - Quick test: if your value contains a colon anywhere, quote the whole value

---

## Step 6 — Fields That Cannot Be Mapped

After all mapping rows, produce this section:

```
## UNMAPPED FIELDS — Cannot be derived from Kobo raw JSON
```

Include every field from Step 1 that falls into one of these categories:

| Category | Reason code | Suggested Action |
|---|---|---|
| Value is `"TBD"` | Placeholder — no mapping yet | Fill field before mapping |
| Value is `"--"` | Empty / not applicable | Leave unmapped |
| Kobo system field (`_id`, `_uuid`, `formhub/uuid`, `meta/instanceID`, `_status`, `_submission_time`, `_submitted_by`, `_tags`, `_notes`, `_geolocation`, `_attachments`, `_validation_status`, `__version__`, `_xform_id_string`, `meta/rootUuid`) | Internal platform metadata | Skip; no Schema.org target |
| No standard Schema.org / DCT / DCAT property exists | No standard target | Store as `additionalProperty` or skip |
| Requires data not in the record | External enrichment needed | Note what data is required |

Format:

```
| Kobo Field Path | Value in Record | Reason Not Mapped | Suggested Action |
|---|---|---|---|
```

---

## Step 7 — Validation Notes

```
## VALIDATION NOTES

- Total Kobo fields found in raw JSON: [N]
- Total fields mapped (rows generated): [N]
- Total fields not mapped: [N]
- Mappings using exactMatch (confidence 1.0): [N]
- Mappings using closeMatch (confidence 0.85–0.9): [N]
- Mappings using relatedMatch (confidence 0.7–0.8): [N]
- New transform rules introduced (not in known list): [list or "none"]
- Fields where human review is required: [list]
- ROR identifiers used — confirmed or flagged?: [list any flagged]
```

---

## Hallucination Guard — Non-Negotiable Rules

1. **Never invent a `source_jsonpath`** not present in the raw JSON from Step 1
2. **Never invent a Schema.org property** — verify at schema.org if unsure
3. **Never invent a ROR identifier** — flag uncertain ones for human review
4. **Never invent a GeoNames ID** — use only the value from `coverage_identifier` in the raw JSON
5. **"TBD" or "--" fields** → unmapped table only, never a mapping row
6. **Uncertain predicate** → use `skos:relatedMatch` with confidence ≤ 0.75 and explain in comment
7. **comment column** → required on every row without exception
8. **Transform rule parameters** → required wherever §4d marks them Required
9. **source_jsonpath** → must start with `$.datasets[*]` on every row without exception
10. **Group-level arrays** → one row per group, sub-field handling in the comment

---

# PROMPT END

---

## Post-Generation Checklist (Run Before Saving the TSV)

```markdown
- [ ] First row is kobo:Dataset with owl:Class categories
- [ ] Every source_jsonpath starts with $.datasets[*]
- [ ] Array groups (creator, publisher, coverage, attributes, subject) each have ONE row, not per-sub-field rows
- [ ] kobo:title maps to schema:name (NOT dct:title)
- [ ] kobo:creator_name maps to schema:creator (NOT schema:name)
- [ ] kobo:publisher_name maps to schema:provider (NOT schema:publisher or schema:name)
- [ ] kobo:coverage_name maps to schema:spatialCoverage (NOT schema:name)
- [ ] kobo:rights maps to schema:isAccessibleForFree with cc_to_boolean (NOT schema:license)
- [ ] kobo:source maps to schema:distribution with datadownload_source (NOT schema:contentUrl)
- [ ] kobo:structure and kobo:geometry map to schema:measurementTechnique with definedterm rule (NOT additionalProperty)
- [ ] kobo:temporalCoverage row present (derived from attributes dates)
- [ ] Transform rules include parameters wherever §4d marks them Required
- [ ] No invented Schema.org properties
- [ ] All "TBD" and "--" values in UNMAPPED table only
- [ ] All Kobo system fields (_id, _uuid, etc.) in UNMAPPED table
- [ ] No duplicate rows if extending an existing SSSOM
- [ ] Confidence scores match predicate types (exactMatch=1.0, closeMatch=0.85–0.9, relatedMatch=0.7–0.8)
- [ ] comment column filled for every row
- [ ] Validation Notes block present and counts reconcile
- [ ] YAML header present if generating from scratch
- [ ] mapping_set_title and mapping_set_description are wrapped in double quotes
- [ ] No colon-space (: ), semicolon, or parenthesis in any unquoted YAML header value
- [ ] No tab characters on any # header line
- [ ] File saved as: sssom/gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv
- [ ] sssom_changelog.md updated with date and summary of changes
```
