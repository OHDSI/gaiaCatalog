"""Validate the catalog's JSON-LD files against the LinkML schema.

Three layers of checks are applied to every datastore/data/<id>/meta_json-ld_<id>.json:

  schema       structure, types, patterns and enums from schema/gaia_catalog.yaml,
               checked through LinkML's JSON Schema validator
  recommended  slots the schema marks recommended but the document lacks
  semantic     rules that span several values (see check_semantics), plus a few
               consistency checks against the sibling meta_etl file

A finding is an ERROR or a WARNING. Required slots and wrong values are errors;
a slot annotated severity=warning in the schema reports value problems as
warnings, and missing recommended slots are warnings.

linkml is imported lazily so that the other masterControl commands do not need it.
"""
import argparse
import json
import logging
import re
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

DEFAULT_SCHEMA = Path(__file__).resolve().parents[2] / 'schema' / 'gaia_catalog.yaml'
ERROR = 'ERROR'
WARNING = 'WARNING'
YEAR = re.compile(r'^(19|20)\d\d$')
INDEX = re.compile(r'/\d+')
SRS_ID = 'Spatial_reference_system'


@dataclass
class Finding:
    """One problem found in a document."""

    severity: str
    layer: str
    path: str
    issue: str
    message: str


@dataclass
class SourceReport:
    """Findings for one catalog source."""

    source: str
    status: str
    errors: int
    warnings: int
    findings: List[Finding]


# ---------------------------------------------------------------------------
# schema layer
# ---------------------------------------------------------------------------
class SchemaChecker:
    """LinkML validation plus the recommended-slot walk."""

    def __init__(self, schema: Path) -> None:
        from linkml.validator import Validator
        from linkml.validator.plugins import JsonschemaValidationPlugin
        from linkml_runtime.utils.schemaview import SchemaView

        self.view = SchemaView(str(schema))
        self.validator = Validator(
            str(schema),
            validation_plugins=[JsonschemaValidationPlugin(closed=True)],
        )
        self.warning_keys: Set[str] = {
            (s.alias or s.name)
            for s in self.view.all_slots().values()
            if 'severity' in (s.annotations or {})
            and str(s.annotations['severity'].value) == 'warning'
        }

    def validate(self, doc: Dict[str, Any]) -> List[Finding]:
        """Return the structural findings for one document."""
        findings = []
        for result in self.validator.validate(doc, target_class='Dataset').results:
            path, text = split_path(result.message)
            key = last_key(path) or required_name(text)
            severity = WARNING if key in self.warning_keys else ERROR
            findings.append(
                Finding(severity, 'schema', generalize(path, text),
                        issue_kind(text), short(text))
            )
        return findings

    def recommended(self, doc: Dict[str, Any]) -> List[Finding]:
        """Return a WARNING for each recommended slot that is absent."""
        findings: List[Finding] = []
        self._walk(doc, 'Dataset', '', findings)
        return findings

    def _walk(self, node: Any, class_name: str, path: str, out: List[Finding]) -> None:
        if not isinstance(node, dict):
            return
        for slot in self.view.class_induced_slots(class_name):
            key = slot.alias or slot.name
            value = node.get(key)
            if slot.recommended and value in (None, '', []):
                out.append(
                    Finding(WARNING, 'recommended', generalize(f'{path}/{key}', ''),
                            'recommended slot missing', f'{key} is recommended')
                )
            if value is None or slot.range not in self.view.all_classes():
                continue
            if slot.range == 'Any':
                continue
            items = value if isinstance(value, list) else [value]
            for i, item in enumerate(items):
                self._walk(item, slot.range, f'{path}/{key}/{i}', out)


def split_path(message: str) -> Tuple[str, str]:
    """Split a LinkML message "<text> in /a/0/b" into (path, text)."""
    match = re.search(r' in (/\S*)$', message)
    if not match:
        return '/', message
    return match.group(1), message[: match.start()]


def last_key(path: str) -> str:
    """The last non-numeric segment of a JSON pointer."""
    parts = [p for p in path.split('/') if p and not p.isdigit()]
    return parts[-1] if parts else ''


def required_name(text: str) -> str:
    """The slot named in "'x' is a required property"."""
    match = re.match(r"'([^']+)' is a required property", text)
    return match.group(1) if match else ''


def generalize(path: str, text: str) -> str:
    """Turn /variableMeasured/12/name into variableMeasured[].name."""
    named = required_name(text)
    segments = [s for s in (path + (f'/{named}' if named else '')).split('/') if s]
    out = ''
    for segment in segments:
        out += '[]' if segment.isdigit() else ('.' if out else '') + segment
    return out or '(document)'


def issue_kind(text: str) -> str:
    """A short, value-free description of what is wrong."""
    for needle, label in (
        ('is a required property', 'missing required slot'),
        ('is not of type', 'wrong type'),
        ('does not match', 'value does not match pattern'),
        ('is not one of', 'value not in enum'),
        ('Additional properties are not allowed', 'unexpected key'),
        ('is too short', 'too few values'),
        ('does not have enough properties', 'too few values'),
        ('is not valid under any of the given schemas', 'value not valid'),
        ('was expected', 'unexpected value'),
    ):
        if needle in text:
            return label
    return short(text, 50)


def short(text: str, limit: int = 110) -> str:
    """Collapse whitespace and truncate."""
    text = ' '.join(text.split())
    return text if len(text) <= limit else text[: limit - 3] + '...'


# ---------------------------------------------------------------------------
# semantic layer
# ---------------------------------------------------------------------------
def terms(doc: Dict[str, Any], set_name: str) -> List[str]:
    """The termCodes of measurementTechnique terms in the named set."""
    out = []
    for term in doc.get('measurementTechnique') or []:
        if not isinstance(term, dict):
            continue
        in_set = term.get('inDefinedTermSet')
        if isinstance(in_set, dict) and in_set.get('name') == set_name:
            out.append(str(term.get('termCode')))
    return out


def check_semantics(doc: Dict[str, Any], folder: str, etl: Dict[str, Any]) -> List[Finding]:
    """Rules that span several values of a document."""
    out: List[Finding] = []

    def add(sev: str, path: str, issue: str, msg: str) -> None:
        out.append(Finding(sev, 'semantic', path, issue, short(msg)))

    context = doc.get('@context')
    if isinstance(context, dict) and context.get('@vocab') != 'https://schema.org/':
        add(ERROR, '@context', 'context', '@context must set @vocab to https://schema.org/')

    doc_id = str(doc.get('@id', ''))
    if doc_id and not doc_id.rstrip('/').endswith(folder):
        add(ERROR, '@id', 'id does not match folder', f'@id does not end with {folder}')

    structure = terms(doc, 'dataRepresentation')
    geometry = terms(doc, 'vectorGeometry')
    if len(structure) != 1:
        add(ERROR, 'measurementTechnique', 'dataRepresentation',
            f'expected one dataRepresentation term, found {len(structure)}')
    elif structure[0] not in ('vector', 'raster', 'table'):
        add(ERROR, 'measurementTechnique', 'dataRepresentation',
            f'dataRepresentation {structure[0]!r} is not vector, raster or table')
    kind = structure[0] if len(structure) == 1 else ''
    if kind == 'vector' and len(geometry) != 1:
        add(ERROR, 'measurementTechnique', 'vector without geometry',
            f'a vector dataset needs one vectorGeometry term, found {len(geometry)}')
    for code in geometry:
        if code not in ('point', 'multipoint', 'linestring', 'multilinestring',
                        'polygon', 'multipolygon'):
            add(ERROR, 'measurementTechnique', 'geometry term', f'unknown geometry {code!r}')
    if kind in ('raster', 'table') and geometry and kind == 'raster':
        add(WARNING, 'measurementTechnique', 'raster with geometry',
            'a raster dataset should not have a vectorGeometry term')

    label = {'vector': 'Vector Dataset', 'raster': 'Raster Dataset'}.get(kind)
    if label and doc.get('type') and doc['type'] != label:
        add(WARNING, 'type', 'type disagrees with structure',
            f'type is {doc["type"]!r} but dataRepresentation is {kind}')

    props = [p for p in doc.get('additionalProperty') or [] if isinstance(p, dict)]
    for prop in props:
        if not (prop.get('name') or prop.get('propertyID')):
            add(ERROR, 'additionalProperty[]', 'property without name',
                'a property needs a name or a propertyID')
    srs = [p for p in props if SRS_ID in str(p.get('propertyID', ''))]
    if kind == 'vector' and not srs:
        add(ERROR, 'additionalProperty', 'no spatial reference',
            'a vector dataset needs a Spatial_reference_system property (EPSG code)')
    for prop in srs:
        if not re.search(r'\d+', str(prop.get('value', ''))):
            add(ERROR, 'additionalProperty[].value', 'srs value',
                f'no EPSG code in {prop.get("value")!r}')

    variables = [v for v in doc.get('variableMeasured') or [] if isinstance(v, dict)]
    names = [str(v.get('name', '')) for v in variables]
    for name in names:
        if name != name.strip():
            add(ERROR, 'variableMeasured[].name', 'name has stray whitespace',
                f'variable name {name!r} has leading or trailing whitespace')
    for name, count in Counter(n.strip() for n in names).items():
        if count > 1:
            add(ERROR, 'variableMeasured[].name', 'duplicate variable',
                f'variable {name!r} appears {count} times')
    for var in variables:
        label = str(var.get('name', '')).strip()
        suspects = [k for k in ('unitCode', 'unitText') if YEAR.match(str(var.get(k, '')))]
        # a real minimum or maximum can fall in 1900-2099, so a year-like
        # minValue only counts when the maximum is absent or also year-like
        if YEAR.match(str(var.get('minValue', ''))) and (
                not var.get('maxValue') or YEAR.match(str(var['maxValue']))):
            suspects.append('minValue')
        for key in suspects:
            add(WARNING, f'variableMeasured[].{key}', 'year-like value',
                f'{label}: {key} is {var[key]!r}, which looks like a year in the wrong column')
        start, end = str(var.get('startDate', '')), str(var.get('endDate', ''))
        if re.match(r'^\d{4}-\d{2}-\d{2}$', start) and re.match(r'^\d{4}-\d{2}-\d{2}$', end) and start > end:
            add(ERROR, 'variableMeasured[]', 'dates reversed',
                f'{label}: startDate {start} is after endDate {end}')
        low, high = to_float(var.get('minValue')), to_float(var.get('maxValue'))
        if low is not None and high is not None and low > high:
            add(WARNING, 'variableMeasured[]', 'min above max',
                f'{label}: minValue {low} is above maxValue {high}')

    attrs = etl.get('attributes')
    if isinstance(attrs, list):
        etl_names = {str(a).split(';')[0].strip() for a in attrs}
        json_names = {n.strip() for n in names}
        if etl_names != json_names:
            diff = len(etl_names ^ json_names)
            add(WARNING, 'variableMeasured', 'variables differ from meta_etl',
                f'{diff} variable name(s) differ between JSON-LD and meta_etl attributes')
    return out


def to_float(value: Any) -> Optional[float]:
    """A float, or None when the value is not a number."""
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# running and reporting
# ---------------------------------------------------------------------------
def read_json(path: Path) -> Optional[Dict[str, Any]]:
    """Load a JSON file or return None (with an error logged)."""
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        logging.error(f'Cannot read {path}: {e}')
        return None


def validate_source(checker: SchemaChecker, data_dir: Path, source: str) -> SourceReport:
    """Validate one source directory."""
    doc = read_json(data_dir / source / f'meta_json-ld_{source}.json')
    if doc is None:
        finding = Finding(ERROR, 'schema', '(document)', 'unreadable',
                          'meta_json-ld file is missing or not valid JSON')
        return SourceReport(source, 'FAIL', 1, 0, [finding])
    etl = read_json(data_dir / source / f'meta_etl_{source}.json') or {}
    findings = checker.validate(doc) + checker.recommended(doc)
    findings += check_semantics(doc, source, etl)
    errors = sum(1 for f in findings if f.severity == ERROR)
    warnings = len(findings) - errors
    status = 'FAIL' if errors else 'WARN' if warnings else 'PASS'
    return SourceReport(source, status, errors, warnings, findings)


def run_validation(
    data_dir: Path,
    schema: Path = DEFAULT_SCHEMA,
    only: Optional[List[str]] = None,
) -> Dict[str, Any]:
    """Validate every source and return the report dictionary."""
    checker = SchemaChecker(schema)
    sources = sorted(
        p.name for p in data_dir.iterdir()
        if (p / f'meta_json-ld_{p.name}.json').exists() and (not only or p.name in only)
    )
    reports = [validate_source(checker, data_dir, s) for s in sources]
    return {
        'generated_at': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC'),
        'schema': str(schema.name),
        'sources': [
            {**asdict(r), 'findings': [asdict(f) for f in r.findings]} for r in reports
        ],
    }


def group_issues(report: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Group findings across sources by (severity, layer, path, issue)."""
    groups: Dict[Tuple[str, str, str, str], Dict[str, Any]] = defaultdict(
        lambda: {'sources': set(), 'count': 0, 'example': '', 'example_source': ''}
    )
    for src in report['sources']:
        for f in src['findings']:
            g = groups[(f['severity'], f['layer'], f['path'], f['issue'])]
            g['sources'].add(src['source'])
            g['count'] += 1
            if not g['example']:
                g['example'], g['example_source'] = f['message'], src['source']
    rows = [
        {'severity': k[0], 'layer': k[1], 'path': k[2], 'issue': k[3],
         'sources': len(v['sources']), 'count': v['count'],
         'example': v['example'], 'example_source': v['example_source']}
        for k, v in groups.items()
    ]
    order = {ERROR: 0, WARNING: 1}
    return sorted(rows, key=lambda r: (order[r['severity']], -r['sources'], r['path']))


def cell(text: str, limit: int = 120) -> str:
    """Make text safe for a markdown table cell."""
    text = ' '.join(str(text).split()).replace('|', '/')
    return text if len(text) <= limit else text[: limit - 3] + '...'


def render_markdown(report: Dict[str, Any]) -> str:
    """Render the report as markdown."""
    sources = report['sources']
    counts = Counter(s['status'] for s in sources)
    lines = [
        '# Catalog JSON-LD validation',
        '',
        f'{len(sources)} sources checked against `{report["schema"]}` on '
        f'{report["generated_at"]}: {counts["PASS"]} pass, {counts["WARN"]} with '
        f'warnings only, {counts["FAIL"]} with errors.',
        '',
        '## Issues by frequency',
        '',
        '| Severity | Layer | Where | Issue | Sources | Count | Example |',
        '|----------|-------|-------|-------|---------|-------|---------|',
    ]
    for g in group_issues(report):
        lines.append(
            f'| {g["severity"]} | {g["layer"]} | `{cell(g["path"], 60)}` | {g["issue"]} | '
            f'{g["sources"]} | {g["count"]} | {g["example_source"]}: {cell(g["example"])} |'
        )
    lines += ['', '## Sources', '', '| Source | Status | Errors | Warnings |',
              '|--------|--------|--------|----------|']
    order = {'FAIL': 0, 'WARN': 1, 'PASS': 2}
    for s in sorted(sources, key=lambda s: (order[s['status']], -s['errors'], s['source'])):
        lines.append(f'| {s["source"]} | {s["status"]} | {s["errors"]} | {s["warnings"]} |')
    return '\n'.join(lines) + '\n'


def add_subcommands(subparsers: Any) -> None:
    """Register the validate_catalog sub-command."""
    vc = subparsers.add_parser(
        'validate_catalog', help='Validate catalog JSON-LD against the LinkML schema'
    )
    vc.add_argument('--data_dir', default='./datastore/data', help='Path to datastore/data')
    vc.add_argument('--schema', default=str(DEFAULT_SCHEMA), help='LinkML schema file')
    vc.add_argument('--results_file', default='./catalog_validation.json', help='JSON output')
    vc.add_argument('--report', default=None, help='Markdown report to write')
    vc.add_argument('--source', action='append', help='Only this source (repeatable)')
    vc.add_argument('--exit_zero', action='store_true', help='Exit 0 even with errors')


def dispatch(args: argparse.Namespace) -> int:
    """Run validate_catalog and return a process exit code."""
    logging.basicConfig(level=logging.INFO)
    report = run_validation(Path(args.data_dir), Path(args.schema), args.source)
    Path(args.results_file).write_text(json.dumps(report, indent=2) + '\n')
    if args.report:
        Path(args.report).write_text(render_markdown(report))
    counts = Counter(s['status'] for s in report['sources'])
    logging.info(f'{len(report["sources"])} sources: {dict(counts)}')
    return 0 if args.exit_zero or not counts['FAIL'] else 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    add_subcommands(sub)
    sys.exit(dispatch(parser.parse_args()))
