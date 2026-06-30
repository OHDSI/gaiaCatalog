#!/usr/bin/env python3
"""
Process an SSSOM mapping file using only core SSSOM semantics.

Unlike sssom_to_jsonld.py, this script does not read JSON input, evaluate
JSONPath expressions, or run transform rules. It parses the mapping set,
optionally validates it with sssom-py (if installed), and exports vocabulary
alignments (subject_id / predicate_id / object_id).

Usage:
    python vanilla_sssom.py --sssom kobo/gaia_metadata_authoring_form_v2_to_schemaorg.sssom.tsv
    python vanilla_sssom.py --sssom test.sssom.tsv --format json --output core.json
    python vanilla_sssom.py --sssom kobo/testing.SSSOM --format tsv --output core.sssom.tsv
    python vanilla_sssom.py --sssom test.sssom.tsv --format turtle --output alignments.ttl
    python vanilla_sssom.py --sssom test.sssom.tsv --validate

Requires:
    pip install pyyaml
    Optional: pip install sssom   # for --validate
    Optional: pip install rdflib  # for --format turtle (also in gaiaCatalog deps)
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import yaml

from sssom_to_jsonld import parse_sssom

CORE_COLUMNS: tuple[str, ...] = (
    'subject_id',
    'subject_label',
    'subject_category',
    'predicate_id',
    'object_id',
    'object_label',
    'object_category',
    'mapping_justification',
    'confidence',
    'comment',
)

EXTENSION_COLUMNS: tuple[str, ...] = (
    'source_jsonpath',
    'target_jsonpath',
    'transform_rule',
    'context_language',
)


def _strip_metadata_extensions(metadata: dict[str, Any]) -> dict[str, Any]:
    """Return metadata without ETL-specific extension definitions."""
    cleaned = dict(metadata)
    cleaned.pop('extension_definitions', None)
    return cleaned


def core_mappings(
    mappings: list[dict[str, str]],
    *,
    include_extensions: bool = False,
) -> list[dict[str, str]]:
    """Keep only standard SSSOM mapping slots (and optionally extension slots)."""
    columns = CORE_COLUMNS + (EXTENSION_COLUMNS if include_extensions else ())
    result: list[dict[str, str]] = []
    for row in mappings:
        kept = {
            col: val.strip()
            for col in columns
            if (val := (row.get(col) or '')).strip()
        }
        if kept:
            result.append(kept)
    return result


def format_summary(metadata: dict[str, Any], mappings: list[dict[str, str]]) -> str:
    """Human-readable summary of the mapping set."""
    lines = [
        f"mapping_set_id:    {metadata.get('mapping_set_id', '(none)')}",
        f"mapping_set_title: {metadata.get('mapping_set_title', '(none)')}",
        f"rows (total):      {len(mappings)}",
        f"rows (core):       {len(core_mappings(mappings))}",
        '',
        'Core alignments:',
        f"{'subject_id':<22} {'predicate_id':<18} {'object_id':<28} conf",
        '-' * 78,
    ]
    for row in core_mappings(mappings):
        lines.append(
            f"{row.get('subject_id', ''):<22} "
            f"{row.get('predicate_id', ''):<18} "
            f"{row.get('object_id', ''):<28} "
            f"{row.get('confidence', '')}"
        )
    extension_rows = sum(
        1 for row in mappings
        if any(row.get(col, '').strip() for col in EXTENSION_COLUMNS)
    )
    if extension_rows:
        lines.extend([
            '',
            f'Note: {extension_rows} row(s) also carry ETL extension columns '
            f'({", ".join(EXTENSION_COLUMNS)}).',
            'Those are ignored here; use sssom_to_jsonld.py to execute them.',
        ])
    return '\n'.join(lines)


def format_json(
    metadata: dict[str, Any],
    mappings: list[dict[str, str]],
    *,
    include_extensions: bool = False,
) -> str:
    """JSON document with metadata and core mapping rows."""
    payload = {
        'metadata': _strip_metadata_extensions(metadata),
        'mappings': core_mappings(mappings, include_extensions=include_extensions),
    }
    return json.dumps(payload, indent=2, ensure_ascii=False)


def format_tsv(metadata: dict[str, Any], mappings: list[dict[str, str]]) -> str:
    """Valid SSSOM/TSV containing only core mapping columns."""
    rows = core_mappings(mappings)
    used_columns = [col for col in CORE_COLUMNS if any(col in row for row in rows)]

    header_lines: list[str] = []
    for key, value in _strip_metadata_extensions(metadata).items():
        if value is None:
            continue
        dumped = yaml.safe_dump({key: value}, default_flow_style=False).strip()
        for line in dumped.splitlines():
            header_lines.append(f'# {line}')

    body = io.StringIO()
    writer = csv.DictWriter(body, fieldnames=used_columns, delimiter='\t', extrasaction='ignore')
    writer.writeheader()
    for row in rows:
        writer.writerow({col: row.get(col, '') for col in used_columns})

    return '\n'.join(header_lines + ['', body.getvalue().rstrip(), ''])


def _expand_curie(curie: str, curie_map: dict[str, str]) -> str:
    if ':' not in curie:
        return curie
    prefix, local = curie.split(':', 1)
    base = curie_map.get(prefix)
    if not base:
        return curie
    if base.endswith(('_', '/')):
        return f'{base}{local}'
    return f'{base}/{local}'


def format_turtle(metadata: dict[str, Any], mappings: list[dict[str, str]]) -> str:
    """RDF/Turtle encoding of core alignments as simple subject predicate object triples."""
    try:
        from rdflib import Graph, Literal, Namespace, URIRef
        from rdflib.namespace import RDF, RDFS, XSD
    except ImportError as exc:
        raise RuntimeError('rdflib is required for --format turtle') from exc

    curie_map = metadata.get('curie_map', {})
    graph = Graph()

    for prefix, uri in curie_map.items():
        graph.bind(prefix, Namespace(uri))

    skos = Namespace(curie_map.get('skos', 'http://www.w3.org/2004/02/skos/core#'))
    sssom_ns = Namespace('https://w3id.org/sssom/')
    graph.bind('sssom', sssom_ns)

    set_uri = URIRef(metadata.get(
        'mapping_set_id',
        'https://example.org/mappings/unnamed',
    ))
    graph.add((set_uri, RDF.type, sssom_ns.MappingSet))
    if title := metadata.get('mapping_set_title'):
        graph.add((set_uri, RDFS.label, Literal(title)))

    for idx, row in enumerate(core_mappings(mappings), start=1):
        mapping_uri = URIRef(f'{set_uri}#mapping/{idx}')
        graph.add((mapping_uri, RDF.type, sssom_ns.Mapping))
        graph.add((set_uri, sssom_ns.mappings, mapping_uri))

        subj = URIRef(_expand_curie(row['subject_id'], curie_map))
        obj = URIRef(_expand_curie(row['object_id'], curie_map))
        pred_local = row['predicate_id'].split(':', 1)[-1]
        predicate = getattr(skos, pred_local, URIRef(_expand_curie(row['predicate_id'], curie_map)))

        graph.add((subj, predicate, obj))
        graph.add((mapping_uri, sssom_ns.subject_id, Literal(row['subject_id'])))
        graph.add((mapping_uri, sssom_ns.object_id, Literal(row['object_id'])))
        graph.add((mapping_uri, sssom_ns.predicate_id, Literal(row['predicate_id'])))

        if justification := row.get('mapping_justification'):
            graph.add((
                mapping_uri,
                sssom_ns.mapping_justification,
                Literal(justification),
            ))
        if confidence := row.get('confidence'):
            graph.add((mapping_uri, sssom_ns.confidence, Literal(confidence, datatype=XSD.decimal)))
        if comment := row.get('comment'):
            graph.add((mapping_uri, RDFS.comment, Literal(comment)))

    return graph.serialize(format='turtle')


def run_validate(sssom_path: Path) -> int:
    """Run sssom-py validation when the sssom CLI is available."""
    try:
        proc = subprocess.run(
            ['sssom', 'validate', str(sssom_path)],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print(
            'sssom CLI not found. Install with: pip install sssom',
            file=sys.stderr,
        )
        return 1

    if proc.stdout.strip():
        print(proc.stdout.strip())
    if proc.stderr.strip():
        print(proc.stderr.strip(), file=sys.stderr)
    return proc.returncode


def main() -> None:
    base = Path(__file__).parent

    parser = argparse.ArgumentParser(
        description='Parse and export core SSSOM alignments (no JSON-LD ETL).',
    )
    parser.add_argument(
        '--sssom',
        type=Path,
        default=base / 'test.sssom.tsv',
        help='SSSOM TSV file',
    )
    parser.add_argument(
        '--format',
        choices=('summary', 'json', 'tsv', 'turtle'),
        default='summary',
        help='Output format (default: summary to stdout)',
    )
    parser.add_argument(
        '--output',
        type=Path,
        default=None,
        help='Write output to this file (default: stdout)',
    )
    parser.add_argument(
        '--include-extensions',
        action='store_true',
        help='Include ETL extension columns in json output',
    )
    parser.add_argument(
        '--validate',
        action='store_true',
        help='Also run sssom-py validation on the input file',
    )
    args = parser.parse_args()

    print(f'Parsing {args.sssom} ...', file=sys.stderr)
    metadata, mappings = parse_sssom(args.sssom)
    print(f'  {len(mappings)} mapping row(s) loaded', file=sys.stderr)

    if args.format == 'summary':
        output_text = format_summary(metadata, mappings)
    elif args.format == 'json':
        output_text = format_json(
            metadata,
            mappings,
            include_extensions=args.include_extensions,
        )
    elif args.format == 'tsv':
        output_text = format_tsv(metadata, mappings)
    else:
        output_text = format_turtle(metadata, mappings)

    if args.output:
        args.output.write_text(output_text, encoding='utf-8')
        print(f'Output written to {args.output}', file=sys.stderr)
    else:
        print(output_text)

    if args.validate:
        code = run_validate(args.sssom)
        if code != 0:
            sys.exit(code)


if __name__ == '__main__':
    main()