#!/usr/bin/env python3
"""
Transform a flat JSON dataset file to JSON-LD using SSSOM mappings.

Reads source_jsonpath / target_jsonpath extension slots from the SSSOM file
to drive the field extraction and renaming. Outputs a JSON-LD document using
the schema.org vocabulary declared in the SSSOM curie_map.

Usage:
    python sssom_to_jsonld.py

Requires:
    pip install pyyaml jsonpath-ng
"""

import csv
import io
import json
import re
from pathlib import Path
from typing import Any, Optional

import yaml
from jsonpath_ng.ext import parse as jp_parse


def parse_sssom(path: Path) -> tuple[dict, list[dict]]:
    """Return (metadata dict, list of mapping rows) from an SSSOM TSV file."""
    header_lines: list[str] = []
    data_lines: list[str] = []

    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("#"):
                header_lines.append(line[2:])  # strip '# ', preserve indentation
            else:
                data_lines.append(line)

    metadata = yaml.safe_load("".join(header_lines)) or {}
    reader = csv.DictReader(io.StringIO("".join(data_lines)), delimiter="\t")
    mappings = [row for row in reader if any(v.strip() for v in row.values())]
    return metadata, mappings


def relative_path(full_path: str, root_path: str) -> str:
    """Convert an absolute source JSONPath to one relative to a matched root item.

    Example: '$.datasets[*].title' with root '$.datasets[*]' -> '$.title'
    """
    root_base = re.sub(r"\[\*\]$", "", root_path)   # '$.datasets[*]' -> '$.datasets'
    suffix = full_path[len(root_base):]              # '[*].title'
    suffix = re.sub(r"^\[\*\]", "", suffix)          # '.title'
    return "$" + suffix                              # '$.title'


def leaf_name(target_jsonpath: str) -> Optional[str]:
    """Extract the property name from a simple '$.name' target JSONPath, else None."""
    m = re.match(r"^\$\.(\w+)$", target_jsonpath.strip())
    return m.group(1) if m else None


def transform(input_data: dict, metadata: dict, mappings: list[dict]) -> dict:
    curie_map = metadata.get("curie_map", {})

    class_row = next((m for m in mappings if m.get("subject_category") == "owl:Class"), None)
    if not class_row:
        raise ValueError("No owl:Class mapping row found — cannot determine source array path.")

    prop_rows = [m for m in mappings if m.get("subject_category") == "owl:ObjectProperty"]
    root_src_path = class_row["source_jsonpath"].strip()
    target_type = class_row["object_id"].strip()   # e.g. 'schema:Dataset'

    source_items = [m.value for m in jp_parse(root_src_path).find(input_data)]

    records: list[dict[str, Any]] = []
    for item in source_items:
        record: dict[str, Any] = {"@type": target_type}

        for row in prop_rows:
            src = row.get("source_jsonpath", "").strip()
            tgt = row.get("target_jsonpath", "").strip()
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
            prop = leaf_name(tgt)
            if prop:
                record[prop] = values if len(values) > 1 else values[0]

        records.append(record)

    schema_base = curie_map.get("schema", "https://schema.org/")
    context = {
        "@vocab": schema_base,
        "schema": schema_base,
    }

    return {"@context": context, "@graph": records}


def main() -> None:
    base = Path(__file__).parent
    sssom_path = base / "test.sssom.tsv"
    input_path = base / "example_input.json"
    output_path = base / "example_output.jsonld"

    print(f"Parsing {sssom_path.name} ...")
    metadata, mappings = parse_sssom(sssom_path)
    print(f"  {len(mappings)} mapping row(s) loaded")

    with open(input_path, encoding="utf-8") as fh:
        input_data = json.load(fh)

    print(f"Transforming {input_path.name} ...")
    jsonld = transform(input_data, metadata, mappings)
    print(f"  {len(jsonld['@graph'])} dataset record(s) mapped")

    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump(jsonld, fh, indent=2, ensure_ascii=False)

    print(f"Output written to {output_path.name}")


if __name__ == "__main__":
    main()
