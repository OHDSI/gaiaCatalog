# SSSOM Extras — Unmapped Field Exploration

This document covers the `kobo_testing.sssom.tsv` experiment: mapping Kobo fields present in
`record_136_raw.json` (and sibling records) that are **not** in the production mapping
`gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv`. It also records the
implementation and verification of three follow-on transform improvements in
`../sssom_to_jsonld.py`.

---

## Directory overview

| File | Description |
|------|-------------|
| `gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv` | Production mapping (25 rows) |
| `kobo_testing.sssom.tsv` | Experimental mapping (54 rows) — production rows + unmapped-field exploration |
| `record_136_raw.json` | Primary test input (PM2.5 vector dataset) |
| `record_26_raw.json`, `record_217_raw.json` | Additional Kobo records for cross-record checks |
| `record_136_keys.txt` | Flat list of 65 top-level Kobo paths in record 136 |
| `pm25_vector_urban.json` | Target reference JSON-LD shape |
| `record_136_output_v2.json` | Output from production mapping |
| `record_136_testing_output.json` | Output from `kobo_testing.sssom.tsv` (after next-step fixes) |
| `../sssom_to_jsonld.py` | Transform engine (one level up) |

The production mapping covers core Dublin Core, ISO, ETL, and cartography fields.
Roughly **40** of the 65 paths in `record_136_keys.txt` are absent from the
production file.

---

## Approach categories in `kobo_testing.sssom.tsv`

Each experimental row tags its strategy in the `comment` column:

| Code | Strategy | When to use |
|------|----------|-------------|
| **A** | `skos:exactMatch` / `closeMatch` to schema.org or Dublin Core | A standard term exists (`usageInfo`, `dct:provenance`, `disambiguatingDescription`) |
| **B** | `additionalProperty` + `property_value` | Operational/Gaia metadata without a schema.org equivalent |
| **C** | `DefinedTerm` | Controlled vocabulary codes (`resource_type`, `data_level`, `status`) |
| **D** | Nested sub-object `transform_rule` | Repeat groups (`sponsor_group`, `file_name_group`, `no_data_group`) |
| **E** | Extend composite rules | Sub-fields of an object already mapped by one rule (`propertyvalue_schema_objects`) |
| **F** | `skos:noMatch` | Kobo envelope fields intentionally excluded |
| **G** | `skip_if` rule chain | Suppress placeholder values (`--`, `TBD`, `not_applicable`) |

### SSSOM design takeaway

SSSOM handles “extra source fields” in layers:

1. **Semantic match** — `skos:exactMatch` / `closeMatch` when a standard predicate exists
2. **`additionalProperty`** — catch-all for operational metadata (works now; noisy at scale)
3. **`DefinedTerm`** — controlled vocabularies
4. **`skos:noMatch`** — document fields you deliberately exclude
5. **`transform_rule` extensions** in `sssom_to_jsonld.py` — structural transforms predicates alone cannot express

---

## Unmapped fields by category (record 136)

| Category | Fields added in `kobo_testing.sssom.tsv` |
|----------|--------------------------------|
| Control | `control_group/id`, `external_id_group` |
| Dublin Core extras | `license_text`, `restrictions`, `provenance`, `resource_type`, `relation_group`, `creator_type` |
| ISO lineage | `lineage`, `process_step`, `processor`, `data_level` |
| Cartography | `label`, `values_group`, `no_data_group`; `attribute_source` / `attribute_external_id` via rule E |
| Collection | `analytic_function`, `analytic_epsg`, `derivatives`, `sponsor_group`, `status`, `disclaimer` |
| ETL extras | `service`, `parameters`, `file_name_group`, `download`, `bash_etl`, `sql_transform` |
| Kobo envelope | `_submission_time`, `_attachments`, etc. → `skos:noMatch` rows |

Records 26 and 217 introduce additional paths (`time_period_start/end`, `band_group`,
`service_definition`, `thumbnail`, etc.) not yet covered — candidates for future rows.

---

## Commands to replicate

All commands assume the repo root is `gaiaCatalog` and use absolute paths for clarity.

### Prerequisites

```bash
cd /home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog
uv sync   # or: pip install pyyaml jsonpath-ng ply
```

### Production baseline (25 rows)

```bash
cd /home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog/mappings/SSSOM

python sssom_to_jsonld.py \
  --sssom  kobo/gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv \
  --input  kobo/record_136_raw.json \
  --output kobo/record_136_output_v2.json \
  --wrap-key datasets
```

### Testing mapping (54 rows)

```bash
python sssom_to_jsonld.py \
  --sssom  kobo/kobo_testing.sssom.tsv \
  --input  kobo/record_136_raw.json \
  --output kobo/record_136_testing_output.json \
  --wrap-key datasets
```

### All three Kobo records

```bash
for rec in 136 26 217; do
  python sssom_to_jsonld.py \
    --sssom  kobo/kobo_testing.sssom.tsv \
    --input  kobo/record_${rec}_raw.json \
    --output kobo/record_${rec}_testing_output.json \
    --wrap-key datasets
done
```

### Compare production vs testing output (new top-level keys)

```bash
cd kobo
python3 -c "
import json
from pathlib import Path

def graph(path):
    return json.loads(Path(path).read_text())['@graph'][0]

v2 = graph('record_136_output_v2.json')
t  = graph('record_136_testing_output.json')
print('NEW keys in testing:', sorted(set(t) - set(v2)))
print('Keys only in v2:    ', sorted(set(v2) - set(t)))
"
```

Expected new keys: `additionalType`, `dct:provenance`, `disambiguatingDescription`,
`funder`, `usageInfo`.

### Verify next-step fixes (skip_if, funder, attribute enrichment)

```bash
cd kobo
python3 -c "
import json
from pathlib import Path

t = json.loads(Path('record_136_testing_output.json').read_text())['@graph'][0]
ap_names = [p.get('name') for p in t.get('additionalProperty', []) if isinstance(p, dict)]

checks = {
    'isRelatedTo suppressed (-- placeholder)': 'isRelatedTo' not in t,
    'lineage suppressed (TBD)': 'lineage' not in ap_names,
    'bash_etl suppressed (TBD)': 'bash_etl' not in ap_names,
    'funder is Organization array': isinstance(t.get('funder'), list) and t['funder'][0].get('@type') == 'Organization',
    'funder count == 3': len(t.get('funder', [])) == 3,
    'attribute_source not lossy on dataset': 'attribute_source' not in ap_names,
}
vm = t['variableMeasured']
with_src = [v['name'] for v in vm if 'sourceOrganization' in v]
with_id  = [v['name'] for v in vm if 'identifier' in v]
checks['all attributes have sourceOrganization'] = len(with_src) == len(vm)
checks['temporal attrs have identifier'] = set(with_id) == {'avpmu_1998', 'avpmu_1999'}

for label, ok in checks.items():
    print(f'{\"PASS\" if ok else \"FAIL\"}: {label}')
"
```

### Compare against reference target

```bash
diff <(jq --sort-keys . kobo/record_136_testing_output.json) \
     <(jq --sort-keys . kobo/pm25_vector_urban.json)
```

Fields still absent (require external data or manual curation) are listed in
`README.md` — e.g. `geo.box`, `hasPart`, `about`, `isBasedOn`, `subjectOf`.

### Unit-test transform rules in isolation

```bash
cd /home/fils/src/Projects/CODATA/INSPIRE/gaiaCatalog/mappings/SSSOM
python3 -c "
import importlib.util
spec = importlib.util.spec_from_file_location('sssom', 'sssom_to_jsonld.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

# skip_if
assert mod.apply_transform('skip_if:values=--,TBD,not_applicable', ['TBD']) is None
assert mod.apply_transform('skip_if:values=--,TBD,not_applicable;string', ['--']) is None
assert mod.apply_transform('skip_if:values=--,TBD,not_applicable;string', ['real']) == 'real'

# sponsor_organization_array
sponsors = mod.apply_transform('sponsor_organization_array', [{
    'collection_group/sponsor_group/sponsor_name': 'IDSC',
    'collection_group/sponsor_group/sponsor_url': 'https://idsc.miami.edu',
}])
assert sponsors['name'] == 'IDSC' and sponsors['url'] == 'https://idsc.miami.edu'

# propertyvalue_schema_objects enrichment
pv = mod.apply_transform('propertyvalue_schema_objects', [{
    'cartography_group/attributes_group/attribute_name': 'pm25',
    'cartography_group/attributes_group/attribute_source': 'SEDAC',
    'cartography_group/attributes_group/attribute_external_id': 'gaia-407',
    'cartography_group/attributes_group/attribute_type': 'numeric',
}])[0]
assert pv['sourceOrganization']['name'] == 'SEDAC'
assert pv['identifier']['value'] == 'gaia-407'

print('All rule unit checks passed.')
"
```

---

## Next-step implementations

Three improvements were added to `../sssom_to_jsonld.py` and wired in `kobo_testing.sssom.tsv`.

### 1. `skip_if` — suppress placeholder values

**Rule syntax:**

```
skip_if:values=--,TBD,not_applicable
skip_if:values=--,TBD,not_applicable;string
skip_if:values=--,TBD,not_applicable;property_value:name=lineage
```

Rules chain with `;`. The first segment filters; later segments transform.

**Implementation note:** Placeholder lists use commas, so `skip_if` parses `values=`
directly rather than using the generic `_parse_kv` comma splitter (which would break
`TBD,not_applicable` into separate tokens).

**Rows using skip_if in `kobo_testing.sssom.tsv`:**

| Subject | Source field | Placeholder in record 136 |
|---------|--------------|---------------------------|
| `kobo:relation_title` | `relation_group/relation_title` | `--` → omitted |
| `kobo:values_field` | `values_group/value_field` | `--` → omitted |
| `kobo:lineage` | `iso_group/lineage` | `TBD` → omitted |
| `kobo:process_step` | `iso_group/process_step` | `TBD` → omitted |
| `kobo:processor` | `iso_group/processor` | `TBD` → omitted |
| `kobo:etl_parameters` | `etl_group/parameters` | `--` → omitted |
| `kobo:bash_etl` | `etl_group/bash_etl` | `TBD` → omitted |
| `kobo:sql_transform` | `etl_group/sql_transform` | `TBD` → omitted |

**Before fix:** `isRelatedTo: "--"` and 5 TBD `additionalProperty` entries polluted output.

**After fix:** Those fields are absent; `additionalProperty` count drops from 19 → 14.

### 2. `sponsor_organization_array` — structured funders

**Rule syntax:**

```
sponsor_organization_array
sponsor_organization_array:name=sponsor_name,url=sponsor_url
```

Maps each `sponsor_group` repeat to a `schema:Organization` on `schema:funder`.

**Before fix:** Single lossy entry:

```json
"funder": {
  "@type": "PropertyValue",
  "name": "sponsor",
  "value": "{'collection_group/sponsor_group/sponsor_name': 'TuftsCTSI', ...}"
}
```

**After fix (record 136):**

```json
"funder": [
  {"@type": "Organization", "name": "TuftsCTSI", "url": "https://www.tuftsctsi.org"},
  {"@type": "Organization", "name": "IDSC", "url": "https://idsc.miami.edu"},
  {"@type": "Organization", "name": "Library", "url": "https://www.library.miami.edu"}
]
```

### 3. `propertyvalue_schema_objects` enrichment — per-attribute provenance

Extended the existing rule; no separate SSSOM rows needed. Removed the interim
`kobo:attribute_source` and `kobo:attribute_external_id` rows from `kobo_testing.sssom.tsv`.

| Kobo sub-field | Schema.org target |
|----------------|-------------------|
| `attribute_source` | `PropertyValue.sourceOrganization` → `Organization.name` |
| `attribute_external_id` | `PropertyValue.identifier` → `PropertyValue` with `propertyID` `https://gdsc.idsc.miami.edu/terms/gaia-attribute-id` |

**Before fix:** Only first attribute's source/ID captured as lossy dataset-level
`additionalProperty` entries (`attribute_source: SEDAC`, `attribute_external_id: gaia-407`).

**After fix:** All 11 `variableMeasured` entries carry `sourceOrganization: SEDAC`;
temporal attributes `avpmu_1998` and `avpmu_1999` also carry structured `identifier`.

Example (`avpmu_1998`):

```json
{
  "@type": "PropertyValue",
  "name": "avpmu_1998",
  "sourceOrganization": {"@type": "Organization", "name": "SEDAC"},
  "identifier": {
    "@type": "PropertyValue",
    "propertyID": "https://gdsc.idsc.miami.edu/terms/gaia-attribute-id",
    "value": "gaia-407"
  }
}
```

---

## Results summary (record 136)

| Metric | Production (`v2`) | Testing (before fixes) | Testing (after fixes) |
|--------|-------------------|------------------------|------------------------|
| SSSOM rows | 25 | 56 | 54 |
| Top-level JSON-LD keys | 22 | 28 | 27 |
| `additionalProperty` count | 1 | 19 | 14 |
| `isRelatedTo: "--"` | absent | present | **absent** |
| `funder` structure | absent | lossy PropertyValue | **3 Organizations** |
| Per-attribute `sourceOrganization` | absent | 1 lossy AP entry | **11/11 variableMeasured** |
| Per-attribute `identifier` | absent | 1 lossy AP entry | **2 temporal attrs** |

### Cross-record testing output

| Record | Top-level keys | `funder` | `additionalProperty` | `variableMeasured` |
|--------|----------------|----------|----------------------|--------------------|
| 136 | 27 | list (3) | 14 | 11 |
| 26 | 25 | list | 12 | 12 |
| 217 | 27 | list | 11 | 1 |

---

## Remaining gaps (future work)

These were noted in the initial exploration and are **not** yet implemented:

| Field / pattern | Issue | Proposed rule |
|-----------------|-------|---------------|
| `no_data_group` | Dict stringified | `no_data_propertyvalue` |
| `file_name_group` | Dict stringified | `file_name_objects` |
| `external_id_type` (`ohdsi;5150`) | Flat string | `external_id_propertyvalue` |
| `derivatives` (`sql shp`) | Flat string | `derivative_datadownload_objects` |
| `creator_type` | Separate AP row | Extend `role_organization_array` |
| `etl_service: not_applicable` | Passes through | Extend `skip_if` placeholders |

Document these as `skos:closeMatch` rows with `PROPOSED_RULE` comments until the
transform engine catches up — the same pattern used in the initial `kobo_testing.sssom.tsv`
draft.

---

## New transform rules reference

| Rule | Behaviour |
|------|-----------|
| `skip_if:values=--,TBD,…` | Return `None` if value matches any placeholder; otherwise pass through |
| `skip_if:…;string` / `skip_if:…;property_value:name=…` | Chain: filter then transform |
| `sponsor_organization_array[:name=…,url=…]` | Array of `Organization` from sponsor repeat group |
| `propertyvalue_schema_objects` (extended) | Adds `sourceOrganization` and `identifier` from attribute sub-fields |

All other rules are documented in `README.md` and the parent
`mappings/SSSOM/README.md`.