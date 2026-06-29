#!/usr/bin/env python3
"""
Transform a flat JSON dataset file to JSON-LD using SSSOM mappings.

Reads source_jsonpath / target_jsonpath / transform_rule extension slots
from the SSSOM file to drive field extraction, transformation, and placement.
Outputs a JSON-LD document using the schema.org vocabulary declared in the
SSSOM curie_map.

Usage:
    python sssom_to_jsonld.py                                      # built-in defaults
    python sssom_to_jsonld.py --sssom FILE --input FILE --output FILE
    python sssom_to_jsonld.py --sssom FILE --input FILE --output FILE --wrap-key datasets

Options:
    --sssom FILE      Path to the SSSOM TSV file
    --input FILE      Path to the source JSON file
    --output FILE     Path for the JSON-LD output file
    --wrap-key KEY    Wrap input as {KEY: [input]} before transforming.
                      Use when input is a single flat record but the SSSOM
                      root path expects an array (e.g. $.datasets[*]).

Requires:
    pip install pyyaml jsonpath-ng ply
"""

import argparse
import csv
import io
import json
import re
from pathlib import Path
from typing import Any, Optional

import yaml
from jsonpath_ng.ext import parse as jp_parse


# ---------------------------------------------------------------------------
# SSSOM parsing
# ---------------------------------------------------------------------------

def parse_sssom(path: Path) -> tuple[dict, list[dict]]:
    """Return (metadata dict, list of mapping rows) from an SSSOM TSV file."""
    header_lines: list[str] = []
    data_lines: list[str] = []

    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("#"):
                header_lines.append(line[2:])
            else:
                data_lines.append(line)

    metadata = yaml.safe_load("".join(header_lines)) or {}
    reader = csv.DictReader(io.StringIO("".join(data_lines)), delimiter="\t")
    mappings = [row for row in reader if any(v.strip() for v in row.values())]
    return metadata, mappings


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def relative_path(full_path: str, root_path: str) -> str:
    """Convert an absolute source JSONPath to one relative to a matched root item.

    Example: '$.datasets[*].title' with root '$.datasets[*]' -> '$.title'
    """
    root_base = re.sub(r"\[\*\]$", "", root_path)
    suffix = full_path[len(root_base):]
    suffix = re.sub(r"^\[\*\]", "", suffix)
    return "$" + suffix


def set_in_record(record: dict, target: str, value: Any) -> None:
    """Write value into record at the location described by a target JSONPath.

    Handles:
      $.prop              simple property; accumulates into an array on repeated writes
      $.prop[*]           always append to an array
      $.prop.subprop      nested write; appends to subprop list on repeated writes
      $.prop[N].subprop   indexed array element then subproperty
      $['key']            bracket-notation top-level key
    """
    t = target.strip()

    # $.prop
    m = re.match(r'^\$\.([A-Za-z_]\w*)$', t)
    if m:
        prop = m.group(1)
        if prop in record:
            existing = record[prop]
            if isinstance(existing, list):
                if isinstance(value, list):
                    existing.extend(value)
                else:
                    existing.append(value)
            else:
                record[prop] = ([existing] + value) if isinstance(value, list) else [existing, value]
        else:
            record[prop] = value
        return

    # $.prop[*]
    m = re.match(r'^\$\.([A-Za-z_]\w*)\[\*\]$', t)
    if m:
        prop = m.group(1)
        if prop not in record:
            record[prop] = []
        if isinstance(value, list):
            record[prop].extend(value)
        else:
            record[prop].append(value)
        return

    # $.prop.subprop
    m = re.match(r'^\$\.([A-Za-z_]\w*)\.([A-Za-z_]\w*)$', t)
    if m:
        prop, subprop = m.group(1), m.group(2)
        if prop not in record or not isinstance(record[prop], dict):
            record[prop] = {}
        container = record[prop]
        if subprop in container:
            existing = container[subprop]
            if isinstance(existing, list):
                if isinstance(value, list):
                    existing.extend(value)
                else:
                    existing.append(value)
            else:
                container[subprop] = ([existing] + value) if isinstance(value, list) else [existing, value]
        else:
            container[subprop] = value if isinstance(value, list) else [value]
        return

    # $.prop[N].subprop
    m = re.match(r'^\$\.([A-Za-z_]\w*)\[(\d+)\]\.([A-Za-z_]\w*)$', t)
    if m:
        prop, idx, subprop = m.group(1), int(m.group(2)), m.group(3)
        if prop not in record:
            record[prop] = []
        arr = record[prop]
        if not isinstance(arr, list):
            arr = []
            record[prop] = arr
        while len(arr) <= idx:
            arr.append({})
        if not isinstance(arr[idx], dict):
            arr[idx] = {}
        arr[idx][subprop] = value
        return

    # $['key']
    m = re.match(r"^\$\['([^']+)'\]$", t)
    if m:
        record[m.group(1)] = value
        return


# ---------------------------------------------------------------------------
# Transform rule lookup tables
# ---------------------------------------------------------------------------

_ROR_LOOKUP: dict[str, str] = {
    "University of Miami GDSC": "https://ror.org/02y3ad647",
    "Geospatial Digital Special Collections (GDSC), University of Miami": "https://ror.org/02y3ad647",
    "Geospatial Digital Special Collections": "https://ror.org/02y3ad647",
}

_GDSC_ROOT_CATALOG: dict = {
    "@type": "DataCatalog",
    "@id": "https://gdsc.idsc.miami.edu",
    "name": "Geospatial Digital Special Collections",
    "url": "https://gdsc.idsc.miami.edu",
}

_EXTENSION_MEDIA_TYPES: dict[str, str] = {
    "zip":     "application/zip",
    "gpkg":    "application/geopackage+sqlite3",
    "geojson": "application/geo+json",
    "json":    "application/json",
    "csv":     "text/csv",
    "pdf":     "application/pdf",
    "tif":     "image/tiff",
    "tiff":    "image/tiff",
    "nc":      "application/x-netcdf",
    "xml":     "application/xml",
}

_FORMAT_MEDIA_TYPES: dict[str, str] = {
    "shp":       "application/x-shapefile",
    "shapefile": "application/x-shapefile",
    "geojson":   "application/geo+json",
    "gpkg":      "application/geopackage+sqlite3",
    "csv":       "text/csv",
    "json":      "application/json",
    "raster":    "image/tiff",
    "tiff":      "image/tiff",
    "netcdf":    "application/x-netcdf",
    "sql":       "application/sql",
}

_ATTR_TYPE_MAP: dict[str, str] = {
    "integer": "xsd:integer",
    "int":     "xsd:integer",
    "string":  "xsd:string",
    "text":    "xsd:string",
    "numeric": "xsd:float",
    "float":   "xsd:float",
    "double":  "xsd:float",
    "boolean": "xsd:boolean",
    "date":    "xsd:date",
}


# ---------------------------------------------------------------------------
# Transform rule implementation
# ---------------------------------------------------------------------------

def _parse_kv(suffix: str) -> dict[str, str]:
    """Parse 'k1=v1,k2=v2' into a dict; values may themselves contain '='."""
    result: dict[str, str] = {}
    for part in suffix.split(","):
        if "=" in part:
            k, v = part.split("=", 1)
            result[k.strip()] = v.strip()
    return result


def _flatten(obj: dict) -> dict:
    """Strip Kobo group path prefixes, keeping only the last path segment as key."""
    return {k.split("/")[-1]: v for k, v in obj.items()}


def apply_transform(rule: str, values: list[Any]) -> Any:
    """Apply a named transform rule to extracted source values.

    Returns the transformed value, or None if the rule produces no output.
    All rules receive the full list of matched values so array-aware rules
    (propertyvalue_schema_objects, date_range_from_attributes) can scan them.

    Rules may be chained with ';' (e.g. skip_if:values=--,TBD;string).
    """
    if not values:
        return None

    if ';' in rule:
        current: Any = values
        for part in rule.split(';'):
            part = part.strip()
            if not part:
                continue
            chunk = current if isinstance(current, list) else [current]
            current = apply_transform(part, chunk)
            if current is None:
                return None
        return current

    # ── skip_if:values=--,TBD,not_applicable ───────────────────────────────
    if rule.startswith('skip_if:'):
        suffix = rule.split(':', 1)[1]
        placeholders_raw = (
            suffix.split('=', 1)[1]
            if suffix.startswith('values=')
            else ''
        )
        placeholders = {
            p.strip()
            for p in placeholders_raw.split(',')
            if p.strip()
        }
        raw = str(values[0]).strip()
        if raw in placeholders:
            return None
        return values[0] if len(values) == 1 else values

    # ── pass-through ────────────────────────────────────────────────────────
    if not rule or rule in ("string", "date", "array", "controlled_value"):
        return values[0] if len(values) == 1 else values

    # ── doi_to_propertyvalue ────────────────────────────────────────────────
    if rule == "doi_to_propertyvalue":
        raw = re.sub(r'^(doi:|https?://doi\.org/)', '', str(values[0]).strip())
        return {
            "@type": "PropertyValue",
            "propertyID": "https://registry.identifiers.org/registry/doi",
            "value": f"doi:{raw}",
            "url": f"https://doi.org/{raw}",
        }

    # ── license_code_to_uri:cc_by=https://…,… ──────────────────────────────
    if rule.startswith("license_code_to_uri"):
        params = _parse_kv(rule.split(":", 1)[1]) if ":" in rule else {}
        raw = str(values[0]).strip()
        return params.get(raw, raw)

    # ── role_organization_array ─────────────────────────────────────────────
    if rule == "role_organization_array":
        out = []
        for v in values:
            flat = _flatten(v) if isinstance(v, dict) else {}
            name = flat.get("creator_name", str(v) if not isinstance(v, dict) else "")
            org: dict[str, Any] = {"@type": "Organization", "name": name}
            if flat.get("creator_affiliation"):
                org["description"] = flat["creator_affiliation"]
            out.append({"@type": "Role", "roleName": "creator", "creator": org})
        return out

    # ── provider_organization_array ─────────────────────────────────────────
    if rule == "provider_organization_array":
        out = []
        for v in values:
            flat = _flatten(v) if isinstance(v, dict) else {}
            name = flat.get("publisher_name", str(v) if not isinstance(v, dict) else "")
            org: dict[str, Any] = {"@type": "Organization", "name": name}
            if name in _ROR_LOOKUP:
                org["@id"] = _ROR_LOOKUP[name]
            out.append(org)
        return out[0] if len(out) == 1 else out

    # ── sponsor_organization_array[:name=…,url=…] ───────────────────────────
    if rule == "sponsor_organization_array" or rule.startswith(
        "sponsor_organization_array:"
    ):
        params = (
            _parse_kv(rule.split(":", 1)[1])
            if rule.startswith("sponsor_organization_array:")
            else {}
        )
        name_field = params.get("name", "sponsor_name")
        url_field = params.get("url", "sponsor_url")
        out = []
        for v in values:
            flat = _flatten(v) if isinstance(v, dict) else {}
            name = flat.get(name_field, str(v) if not isinstance(v, dict) else "")
            org: dict[str, Any] = {"@type": "Organization", "name": name}
            if flat.get(url_field):
                org["url"] = flat[url_field]
            out.append(org)
        return out[0] if len(out) == 1 else out

    # ── place_object_with_geonames ──────────────────────────────────────────
    if rule == "place_object_with_geonames":
        places = []
        for v in values:
            flat = _flatten(v) if isinstance(v, dict) else {}
            place: dict[str, Any] = {
                "@type": "Place",
                "name": flat.get("coverage_name", str(v) if not isinstance(v, dict) else ""),
            }
            identifier = flat.get("coverage_identifier")
            schema_uri = flat.get("coverage_identifier_schema_uri", "").rstrip("/")
            schema_name = flat.get("coverage_identifier_schema", "identifier")
            if identifier and schema_uri:
                place["additionalProperty"] = [{
                    "@type": "PropertyValue",
                    "name": schema_name,
                    "value": identifier,
                    "url": f"{schema_uri}/{identifier}",
                }]
            places.append(place)
        return places[0] if len(places) == 1 else places

    # ── datacatalog_objects ─────────────────────────────────────────────────
    if rule == "datacatalog_objects":
        tokens = str(values[0]).split()
        catalogs: list[dict] = [_GDSC_ROOT_CATALOG]
        for token in tokens:
            url = f"https://gdsc.idsc.miami.edu/?collection={token}"
            catalogs.append({"@type": "DataCatalog", "name": token, "@id": url, "url": url})
        return catalogs

    # ── definedterm:termSet=…,termSetUrl=…,name=… ──────────────────────────
    if rule.startswith("definedterm:"):
        params = _parse_kv(rule.split(":", 1)[1])
        term_code = str(values[0]).strip()
        return {
            "@type": "DefinedTerm",
            "name": params.get("name", term_code),
            "termCode": term_code,
            "inDefinedTermSet": {
                "@type": "DefinedTermSet",
                "name": params.get("termSet", ""),
                "url": params.get("termSetUrl", ""),
            },
        }

    # ── srs_propertyvalue:uriTemplate=… ────────────────────────────────────
    if rule.startswith("srs_propertyvalue:"):
        params = _parse_kv(rule.split(":", 1)[1])
        val = str(values[0]).strip()
        uri = params.get("uriTemplate", "{value}").replace("{value}", val)
        return {"@type": "PropertyValue", "name": "Spatial Reference System", "value": uri}

    # ── datadownload_source:type=…,name=… ──────────────────────────────────
    if rule.startswith("datadownload_source:"):
        params = _parse_kv(rule.split(":", 1)[1])
        return [{
            "@type": params.get("type", "DataDownload"),
            "name": params.get("name", "Source distribution"),
            "contentUrl": str(values[0]).strip(),
        }]

    # ── extension_to_media_type_or_string ───────────────────────────────────
    if rule == "extension_to_media_type_or_string":
        val = str(values[0]).strip().lower()
        return _EXTENSION_MEDIA_TYPES.get(val, val)

    # ── format_to_media_type_or_string ──────────────────────────────────────
    if rule == "format_to_media_type_or_string":
        val = str(values[0]).strip().lower()
        return _FORMAT_MEDIA_TYPES.get(val, val)

    # ── property_value:name=… ───────────────────────────────────────────────
    if rule.startswith("property_value:"):
        params = _parse_kv(rule.split(":", 1)[1])
        return {
            "@type": "PropertyValue",
            "name": params.get("name", "value"),
            "value": str(values[0]).strip(),
        }

    # ── propertyvalue_schema_objects ────────────────────────────────────────
    if rule == "propertyvalue_schema_objects":
        out = []
        for v in values:
            if not isinstance(v, dict):
                out.append({"@type": "PropertyValue", "name": str(v)})
                continue
            flat = _flatten(v)
            pv: dict[str, Any] = {
                "@type": "PropertyValue",
                "name": flat.get("attribute_name", ""),
                "description": flat.get("attribute_description", ""),
            }
            attr_type = flat.get("attribute_type", "").lower()
            if attr_type:
                pv["qudt:dataType"] = _ATTR_TYPE_MAP.get(attr_type, f"xsd:{attr_type}")
            if flat.get("attribute_unit"):
                pv["unitText"] = flat["attribute_unit"]
            if flat.get("attribute_unit_concept_id"):
                pv["unitCode"] = flat["attribute_unit_concept_id"]
            if flat.get("attribute_concept_id"):
                pv["alternateName"] = flat["attribute_concept_id"]
            if flat.get("attribute_source"):
                pv["sourceOrganization"] = {
                    "@type": "Organization",
                    "name": flat["attribute_source"],
                }
            if flat.get("attribute_external_id"):
                pv["identifier"] = {
                    "@type": "PropertyValue",
                    "propertyID": "https://gdsc.idsc.miami.edu/terms/gaia-attribute-id",
                    "value": flat["attribute_external_id"],
                }
            start = flat.get("attribute_start_date")
            end = flat.get("attribute_end_date")
            if start and end:
                pv["additionalProperty"] = [{
                    "@type": "PropertyValue",
                    "name": "temporal_interval",
                    "value": f"{start}/{end}",
                }]
            out.append(pv)
        return out

    # ── date_range_from_attributes:start=…,end=… ───────────────────────────
    if rule.startswith("date_range_from_attributes:"):
        params = _parse_kv(rule.split(":", 1)[1])
        start_field = params.get("start", "attribute_start_date")
        end_field = params.get("end", "attribute_end_date")
        starts, ends = [], []
        for v in values:
            if isinstance(v, dict):
                flat = _flatten(v)
                if flat.get(start_field):
                    starts.append(flat[start_field])
                if flat.get(end_field):
                    ends.append(flat[end_field])
        if starts and ends:
            return f"{min(starts)}/{max(ends)}"
        return None

    # ── cc_to_boolean ───────────────────────────────────────────────────────
    if rule == "cc_to_boolean":
        return "creativecommons.org" in str(values[0])

    # ── default: pass through ───────────────────────────────────────────────
    return values[0] if len(values) == 1 else values


# ---------------------------------------------------------------------------
# Core transform
# ---------------------------------------------------------------------------

def transform(input_data: dict, metadata: dict, mappings: list[dict]) -> dict:
    curie_map = metadata.get("curie_map", {})

    class_row = next((m for m in mappings if m.get("subject_category") == "owl:Class"), None)
    if not class_row:
        raise ValueError("No owl:Class mapping row found — cannot determine source array path.")

    prop_rows = [m for m in mappings if m.get("subject_category") == "owl:ObjectProperty"]
    root_src_path = class_row["source_jsonpath"].strip()
    target_type = class_row["object_id"].strip()
    class_rule = class_row.get("transform_rule", "").strip()

    source_items = [m.value for m in jp_parse(root_src_path).find(input_data)]

    records: list[dict[str, Any]] = []
    for item in source_items:
        record: dict[str, Any] = {"@type": target_type}

        if class_rule == "create_dataset_object_with_id":
            table_name = item.get("etl_group/table_name", "")
            if table_name:
                record["@id"] = f"https://gdsc.idsc.miami.edu/detail/{table_name}"

        for row in prop_rows:
            src = row.get("source_jsonpath", "").strip()
            tgt = row.get("target_jsonpath", "").strip()
            rule = row.get("transform_rule", "").strip()
            if not src or not tgt:
                continue

            rel = relative_path(src, root_src_path)
            try:
                matches = jp_parse(rel).find(item)
            except Exception:
                continue
            if not matches:
                continue

            values = [m.value for m in matches]
            transformed = apply_transform(rule, values)
            if transformed is None:
                continue

            set_in_record(record, tgt, transformed)

        records.append(record)

    schema_base = curie_map.get("schema", "https://schema.org/")
    context: dict[str, Any] = {"@vocab": schema_base, "schema": schema_base}

    if class_rule == "create_dataset_object_with_id":
        context["@language"] = "en"
        for prefix in ("dct", "dcat", "qudt", "unit", "xsd", "pato"):
            if prefix in curie_map:
                context[prefix] = curie_map[prefix]

    return {"@context": context, "@graph": records}


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    base = Path(__file__).parent

    parser = argparse.ArgumentParser(description="Transform JSON to JSON-LD using an SSSOM mapping file.")
    parser.add_argument("--sssom",    type=Path, default=base / "test.sssom.tsv",
                        help="SSSOM TSV file")
    parser.add_argument("--input",    type=Path, default=base / "example_input.json",
                        help="Source JSON file")
    parser.add_argument("--output",   type=Path, default=base / "example_output.jsonld",
                        help="Output JSON-LD file")
    parser.add_argument("--wrap-key", type=str,  default=None,
                        help="Wrap a single flat input record as {KEY: [record]} before transforming")
    args = parser.parse_args()

    print(f"Parsing {args.sssom} ...")
    metadata, mappings = parse_sssom(args.sssom)
    print(f"  {len(mappings)} mapping row(s) loaded")

    with open(args.input, encoding="utf-8") as fh:
        input_data = json.load(fh)

    if args.wrap_key:
        input_data = {args.wrap_key: [input_data] if not isinstance(input_data, list) else input_data}

    print(f"Transforming {args.input} ...")
    jsonld = transform(input_data, metadata, mappings)
    print(f"  {len(jsonld['@graph'])} dataset record(s) mapped")

    with open(args.output, "w", encoding="utf-8") as fh:
        json.dump(jsonld, fh, indent=2, ensure_ascii=False)

    print(f"Output written to {args.output}")


if __name__ == "__main__":
    main()
