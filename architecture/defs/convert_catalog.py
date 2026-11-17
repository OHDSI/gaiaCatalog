"""Convert catalog JSON-LD between the flat form (v1) and the graph form (v2).

v1 is the flat schema.org document gaiaDB ingests (schema/gaia_catalog.yaml).
v2 is the {"@context", "@graph": [Dataset]} form from commit 4589614
(schema/gaia_catalog_v2.yaml).

v1 to v2 keeps everything in the v1 document, so v2 to v1 gives back the same
document in normal form (see normalize_v1). The v2 form also holds values that
v1 cannot (funder, usageInfo, ETL settings, the data-processing-level term); they
are dropped on the way back, and `enrich_from_etl` can add a few of them from
meta_etl on the way forward.

Mapping, v1 to v2:

  @language                      inLanguage (and @language in the context)
  type                           additionalType
  creator[agent]                 creator[Role{roleName: creator, creator: agent}]
  spatialCoverage[place, bbox]   spatialCoverage[place + additionalProperty
                                 {geonames, Spatial Reference System, extent}]
  additionalProperty (EPSG)      the Spatial Reference System property of the place
  measurementTechnique term      same termCode, named by its term set
  distribution (strings)         distribution[DataDownload{contentUrl}]
  variable propertyID            variable alternateName
  variable "xsd"-less dataType   qudt:dataType with the xsd: prefix
  variable startDate/endDate     additionalProperty temporal_interval "start/end"
  everything else                unchanged
"""
import argparse
import copy
import json
import logging
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

GEONAMES = re.compile(r'^https://www\.geonames\.org/(\d+)$')
EPSG_V1 = re.compile(r'^https://epsg\.io/(\d+)$')
EPSG_V2 = re.compile(r'^http://www\.opengis\.net/def/crs/EPSG/0/(\d+)$')
ENVELOPE = re.compile(r'^ENVELOPE\(([^,]+),([^,]+),([^,]+),([^)]+)\)$')
PARTIAL = re.compile(r'^\d{4}(-\d{2}(-\d{2})?)?$')
SRS_PROPERTY_ID = 'http://dbpedia.org/resource/Spatial_reference_system'
SRS_NAME = 'Spatial Reference System'
VOCAB = 'https://gdsc.idsc.miami.edu/vocab/'

TERM_NAMES = {'dataRepresentation': 'GIS Data Structure',
              'vectorGeometry': 'GIS Vector Geometry'}
V1_TERM_DESCRIPTIONS = {'dataRepresentation': 'GIS Data Structure for Representation',
                        'vectorGeometry': 'GIS Vector Geometry'}
V1_TERM_CHOICES = {'dataRepresentation': ['raster', 'vector', 'table'],
                   'vectorGeometry': ['point', 'line', 'polygon']}

V1_CONTEXT = {
    '@vocab': 'https://schema.org/',
    'dct': 'http://purl.org/dc/terms/',
    'qudt': 'http://qudt.org/schema/qudt/',
    'quantitykind': 'http://qudt.org/vocab/quantitykind/',
    'unit': 'http://qudt.org/vocab/unit/',
    'xsd': 'http://www.w3.org/2001/XMLSchema',
    'extendedConstraintProperty': 'http://codata.org/vocab/extendedConstraintProperty',
    'sdmx': 'https://sdmx.org',
}
V2_CONTEXT = {
    '@vocab': 'https://schema.org/',
    'schema': 'https://schema.org/',
    'dct': 'http://purl.org/dc/terms/',
    'qudt': 'http://qudt.org/schema/qudt/',
    'xsd': 'http://www.w3.org/2001/XMLSchema#',
}

V1_KEYS = {
    '@context', '@type', '@id', '@language', 'name', 'description', 'version', 'url',
    'creator', 'provider', 'license', 'spatialCoverage', 'datePublished',
    'dateModified', 'temporalCoverage', 'keywords', 'type', 'about',
    'measurementTechnique', 'additionalProperty', 'variableMeasured', 'distribution',
    'includedInDataCatalog', 'isBasedOn',
}
V1_VARIABLE_KEYS = {
    '@type', 'name', 'description', 'propertyID', 'qudt:dataType', 'unitText',
    'unitCode', 'minValue', 'maxValue', 'startDate', 'endDate',
}
# v1 fields copied unchanged into the v2 node
COPIED = ('name', 'description', 'url', 'datePublished', 'dateModified', 'keywords',
          'license', 'temporalCoverage', 'version')


class ConversionError(ValueError):
    """Raised when a document has a shape the converter cannot map."""


# ---------------------------------------------------------------------------
# v1 -> v2
# ---------------------------------------------------------------------------
def flat_to_v2(flat: Dict[str, Any], etl: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Convert a flat (v1) document to the graph (v2) form.

    Args:
        flat: The v1 document.
        etl: Optional meta_etl content, used to add a few v2-only values.

    Raises:
        ConversionError: if the document has keys the converter does not know.
    """
    unknown = set(flat) - V1_KEYS
    if unknown:
        raise ConversionError(f'unknown v1 keys: {sorted(unknown)}')
    language = flat.get('@language')
    context = dict(V2_CONTEXT)
    if language:
        context = {'@language': language, **context}

    node: Dict[str, Any] = {'@type': 'schema:Dataset', '@id': flat['@id']}
    for key in ('name', 'description', 'url'):
        if key in flat:
            node[key] = flat[key]
    if language:
        node['inLanguage'] = language
    for key in ('datePublished', 'dateModified'):
        if key in flat:
            node[key] = flat[key]
    node['creator'] = [
        {'@type': 'Role', 'roleName': 'creator', 'creator': copy.deepcopy(agent)}
        for agent in flat.get('creator', [])
    ]
    node['provider'] = copy.deepcopy(flat.get('provider', []))
    places, remaining = spatial_to_v2(flat)
    node['spatialCoverage'] = places
    for key in ('keywords', 'includedInDataCatalog'):
        if key in flat:
            node[key] = copy.deepcopy(flat[key])
    node['measurementTechnique'] = [term_to_v2(t) for t in flat.get('measurementTechnique', [])]
    node['distribution'] = [
        {'@type': 'DataDownload', 'name': 'Source distribution', 'contentUrl': url}
        for url in as_list(flat.get('distribution'))
    ]
    node['additionalProperty'] = remaining
    if 'type' in flat:
        node['additionalType'] = flat['type']
    for key in ('license', 'temporalCoverage'):
        if key in flat:
            node[key] = flat[key]
    node['variableMeasured'] = [variable_to_v2(v) for v in flat.get('variableMeasured', [])]
    for key in ('version', 'about', 'isBasedOn'):
        if key in flat:
            node[key] = copy.deepcopy(flat[key])
    if etl:
        enrich_from_etl(node, etl)
    return {'@context': context, '@graph': [node]}


def as_list(value: Any) -> List[Any]:
    """A list from None, a scalar or a list."""
    if value is None:
        return []
    return list(value) if isinstance(value, list) else [value]


def prop(name: str, value: Any, **extra: Any) -> Dict[str, Any]:
    """A PropertyValue node."""
    return {'@type': 'PropertyValue', 'name': name, 'value': value, **extra}


def spatial_to_v2(flat: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Build the v2 places and the v2 additionalProperty list from v1.

    The first place carries the geonames id, the reference system and the extent.
    Returns (places, remaining additionalProperty entries).
    """
    boxes = [p for p in flat.get('spatialCoverage', []) if 'geo' in p]
    named = [copy.deepcopy(p) for p in flat.get('spatialCoverage', []) if 'geo' not in p]
    if len(boxes) > 1 or any(b.get('name') != 'bbox' for b in boxes):
        raise ConversionError('spatialCoverage: expected at most one place named bbox with geo')
    srs = None
    remaining = []
    for item in flat.get('additionalProperty', []):
        if srs is None and SRS_PROPERTY_ID in str(item.get('propertyID', '')):
            srs = item
        else:
            remaining.append(rewrite_property(item))
    if not named:
        raise ConversionError('spatialCoverage: expected a named place')
    if named:
        first, props = named[0], []
        match = GEONAMES.match(first.get('@id', ''))
        if match:
            props.append(prop('geonames', match.group(1), url=first.pop('@id')))
        if srs is not None:
            props.append(prop(SRS_NAME, srs_to_v2(srs['value'])))
        if boxes:
            props.append(prop('extent', polygon_to_extent(boxes[0]['geo']['polygon'])))
        if props:
            first['additionalProperty'] = props
    return named, remaining


def rewrite_property(item: Dict[str, Any]) -> Dict[str, Any]:
    """A flat additionalProperty entry as a v2 entry (unchanged, typed)."""
    out = copy.deepcopy(item)
    out.setdefault('@type', 'PropertyValue')
    return out


def srs_to_v2(value: Any) -> Any:
    """https://epsg.io/4269 becomes the OGC URI; anything else is kept."""
    match = EPSG_V1.match(str(value))
    return f'http://www.opengis.net/def/crs/EPSG/0/{match.group(1)}' if match else value


def polygon_to_extent(polygon: str) -> str:
    """A closed lat/lon rectangle becomes ENVELOPE(west,east,north,south)."""
    t = polygon.split()
    rect = (len(t) == 10 and t[0] == t[2] == t[8] and t[1] == t[7] == t[9]
            and t[3] == t[5] and t[4] == t[6])
    if not rect:
        return polygon
    return f'ENVELOPE({t[1]},{t[3]},{t[4]},{t[0]})'


def set_name_of(term: Dict[str, Any]) -> Optional[str]:
    """The name of the term set of a term (the set may be a node or just its name)."""
    in_set = term.get('inDefinedTermSet')
    return in_set.get('name') if isinstance(in_set, dict) else in_set


def term_to_v2(term: Dict[str, Any]) -> Dict[str, Any]:
    """A measurementTechnique term, named by its term set."""
    set_name = set_name_of(term)
    return {
        '@type': 'DefinedTerm',
        'name': TERM_NAMES.get(set_name, set_name),
        'termCode': term['termCode'],
        'inDefinedTermSet': {'@type': 'DefinedTermSet', 'name': set_name,
                             'url': f'{VOCAB}{set_name}'},
    }


def variable_to_v2(var: Dict[str, Any]) -> Dict[str, Any]:
    """A variableMeasured entry in v2 form."""
    unknown = set(var) - V1_VARIABLE_KEYS
    if unknown:
        raise ConversionError(f'variable {var.get("name")!r}: unknown keys {sorted(unknown)}')
    out: Dict[str, Any] = {'@type': 'PropertyValue', 'name': var['name']}
    if 'description' in var:
        out['description'] = var['description']
    if 'qudt:dataType' in var:
        data_type = str(var['qudt:dataType'])
        out['qudt:dataType'] = data_type if ':' in data_type else f'xsd:{data_type}'
    for key in ('unitText', 'unitCode'):
        if key in var:
            out[key] = var[key]
    if 'propertyID' in var:
        out['alternateName'] = var['propertyID']
    for key in ('minValue', 'maxValue'):
        if key in var:
            out[key] = var[key]
    start, end = var.get('startDate'), var.get('endDate')
    if start or end:
        if all(v is None or PARTIAL.match(str(v)) for v in (start, end)):
            out['additionalProperty'] = [
                prop('temporal_interval', f'{start or ""}/{end or ""}')]
        else:   # not ISO (for example 1/1/18): keep each date as written
            out['additionalProperty'] = [
                prop(k, v) for k, v in (('startDate', start), ('endDate', end)) if v]
    return out


def enrich_from_etl(node: Dict[str, Any], etl: Dict[str, Any]) -> None:
    """Add the v2-only values that meta_etl states directly."""
    if etl.get('update_frequency'):
        node['dct:accrualPeriodicity'] = etl['update_frequency']
    extra = []
    for name, key in (('postgis_table', 'table'), ('download_method', 'download'),
                      ('customEtl', 'custom_etl')):
        if etl.get(key):
            extra.append(prop(name, etl[key]))
    node['additionalProperty'] = extra + node['additionalProperty']


# ---------------------------------------------------------------------------
# v2 -> v1
# ---------------------------------------------------------------------------
def v2_to_flat(doc: Dict[str, Any]) -> Dict[str, Any]:
    """Convert a graph (v2) document to the flat (v1) form, in normal form.

    Values that v1 cannot hold are dropped. A missing version is taken from the
    date of dateModified, because gaiaDB needs one.
    """
    graph = doc.get('@graph')
    if not isinstance(graph, list) or len(graph) != 1:
        raise ConversionError('expected an @graph with exactly one node')
    node = graph[0]
    context = doc.get('@context') or {}
    language = node.get('inLanguage') or context.get('@language')

    out: Dict[str, Any] = {'@context': copy.deepcopy(V1_CONTEXT), '@type': 'Dataset',
                           '@id': node['@id']}
    if 'includedInDataCatalog' in node:
        out['includedInDataCatalog'] = copy.deepcopy(as_list(node['includedInDataCatalog']))
    for key in ('name',):
        if key in node:
            out[key] = node[key]
    out['creator'] = [
        copy.deepcopy(role['creator']) if isinstance(role, dict) and 'creator' in role
        else copy.deepcopy(role)
        for role in as_list(node.get('creator'))
    ]
    if 'url' in node:
        out['url'] = node['url']
    out['provider'] = copy.deepcopy(as_list(node.get('provider')))
    out['spatialCoverage'], srs = spatial_to_v1(node)
    if 'additionalType' in node:
        out['type'] = node['additionalType']
    for key in ('datePublished', 'temporalCoverage', 'description'):
        if key in node:
            out[key] = node[key]
    if 'keywords' in node:
        out['keywords'] = as_list(node['keywords'])
    if language:
        out['@language'] = language
    out['measurementTechnique'] = [
        t for t in (term_to_v1(x) for x in as_list(node.get('measurementTechnique'))) if t]
    props = ([srs] if srs else []) + [
        flat_property(p) for p in as_list(node.get('additionalProperty'))
        if 'propertyID' in p or p.get('name') == 'temporalDimension'
        or str(p.get('name', '')).startswith('http')
    ]
    if props:
        out['additionalProperty'] = props
    if 'about' in node:
        out['about'] = copy.deepcopy(node['about'])
    out['variableMeasured'] = [variable_to_v1(v) for v in as_list(node.get('variableMeasured'))]
    if 'isBasedOn' in node:
        out['isBasedOn'] = copy.deepcopy(node['isBasedOn'])
    out['distribution'] = [d['contentUrl'] for d in as_list(node.get('distribution'))
                           if isinstance(d, dict) and 'contentUrl' in d]
    if 'dateModified' in node:
        out['dateModified'] = node['dateModified']
    version = node.get('version') or str(node.get('dateModified', ''))[:10]
    if version:
        out['version'] = version
    if 'license' in node:
        out['license'] = node['license']
    return out


def flat_property(item: Dict[str, Any]) -> Dict[str, Any]:
    """A v2 additionalProperty entry as a flat one (without the added @type)."""
    return copy.deepcopy(item)


def spatial_to_v1(node: Dict[str, Any]) -> Tuple[List[Dict[str, Any]], Optional[Dict[str, Any]]]:
    """Build v1 places (with the bbox last) and the EPSG property from v2."""
    places = [copy.deepcopy(p) for p in as_list(node.get('spatialCoverage'))]
    srs_value, extent = None, None
    for i, place in enumerate(places):
        keep = []
        for item in as_list(place.pop('additionalProperty', None)):
            name = item.get('name')
            if name == 'geonames':
                place['@id'] = item.get('url') or f'https://www.geonames.org/{item["value"]}'
            elif name == SRS_NAME and srs_value is None:
                srs_value = item['value']
            elif name == 'extent' and extent is None:
                extent = item['value']
            else:
                keep.append(item)
        if keep:
            place['additionalProperty'] = keep
        places[i] = {k: place[k] for k in ('@id', '@type', 'name') if k in place}
    if srs_value is None:   # some v2 files list the reference system at the top
        for item in as_list(node.get('additionalProperty')):
            if item.get('name') == SRS_NAME:
                srs_value = item['value']
                break
    if extent is not None:
        places.append({'@type': 'Place', 'name': 'bbox',
                       'geo': {'@type': 'GeoShape', 'polygon': extent_to_polygon(extent)}})
    srs = None
    if srs_value is not None:
        srs = {'@type': 'PropertyValue', 'propertyID': SRS_PROPERTY_ID,
               'value': srs_to_v1(srs_value)}
    return places, srs


def srs_to_v1(value: Any) -> Any:
    """The OGC URI becomes https://epsg.io/<code>; anything else is kept."""
    match = EPSG_V2.match(str(value))
    return f'https://epsg.io/{match.group(1)}' if match else value


def extent_to_polygon(extent: str) -> str:
    """ENVELOPE(west,east,north,south) becomes a closed lat/lon rectangle."""
    match = ENVELOPE.match(extent)
    if not match:
        return extent
    west, east, north, south = match.groups()
    return f'{south} {west} {south} {east} {north} {east} {north} {west} {south} {west}'


def term_to_v1(term: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """A v2 measurementTechnique term as a v1 term; None for terms v1 has no set for."""
    set_name = set_name_of(term)
    if set_name not in V1_TERM_DESCRIPTIONS:
        return None
    return {
        '@type': 'DefinedTerm',
        'description': V1_TERM_DESCRIPTIONS[set_name],
        'inDefinedTermSet': {
            '@type': 'DefinedTermSet',
            'name': set_name,
            'hasDefinedTerm': [{'@type': 'DefinedTerm', 'termCode': c}
                               for c in V1_TERM_CHOICES[set_name]],
        },
        'termCode': term['termCode'],
    }


def variable_to_v1(var: Dict[str, Any]) -> Dict[str, Any]:
    """A v2 variableMeasured entry as a v1 entry."""
    out: Dict[str, Any] = {'@type': 'PropertyValue', 'name': var['name']}
    if 'description' in var:
        out['description'] = var['description']
    if 'alternateName' in var:
        out['propertyID'] = var['alternateName']
    if 'qudt:dataType' in var:
        out['qudt:dataType'] = re.sub(r'^xsd:', '', str(var['qudt:dataType']))
    for key in ('unitText', 'unitCode', 'minValue', 'maxValue'):
        if key in var:
            out[key] = var[key]
    for item in as_list(var.get('additionalProperty')):
        if item.get('name') == 'temporal_interval':
            start, _, end = str(item['value']).partition('/')
            if start:
                out['startDate'] = start
            if end:
                out['endDate'] = end
        elif item.get('name') in ('startDate', 'endDate'):
            out[item['name']] = item['value']
    return out


# ---------------------------------------------------------------------------
# normal form and checks
# ---------------------------------------------------------------------------
def normalize_v1(flat: Dict[str, Any]) -> Dict[str, Any]:
    """The v1 normal form that v2_to_flat produces.

    It standardizes what v2 does not carry: the context, the descriptions and
    choice lists of measurementTechnique terms, distribution as a list, and the
    order of additionalProperty entries.
    """
    doc = copy.deepcopy(flat)
    doc['@context'] = copy.deepcopy(V1_CONTEXT)
    if 'distribution' in doc:
        doc['distribution'] = as_list(doc['distribution'])
    doc['measurementTechnique'] = [
        t for t in (term_to_v1(x) for x in doc.get('measurementTechnique', [])) if t]
    if 'additionalProperty' in doc:
        doc['additionalProperty'] = sorted(
            doc['additionalProperty'],
            key=lambda p: (SRS_PROPERTY_ID not in str(p.get('propertyID')),
                           json.dumps(p, sort_keys=True)))
    return doc


def round_trip_diff(flat: Dict[str, Any]) -> List[str]:
    """Top-level keys whose value changes in flat -> v2 -> flat (normal form)."""
    expected = normalize_v1(flat)
    got = normalize_v1(v2_to_flat(flat_to_v2(flat)))
    return sorted(k for k in set(expected) | set(got) if expected.get(k) != got.get(k))


# ---------------------------------------------------------------------------
# command line
# ---------------------------------------------------------------------------
def read_json(path: Path) -> Optional[Dict[str, Any]]:
    """Load a JSON file, or return None."""
    try:
        return json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        logging.error(f'Cannot read {path}: {e}')
        return None


def add_subcommands(subparsers: Any) -> None:
    """Register the convert_catalog sub-command."""
    cc = subparsers.add_parser(
        'convert_catalog', help='Convert catalog JSON-LD between the flat (v1) and graph (v2) form'
    )
    cc.add_argument('--direction', choices=['v1_to_v2', 'v2_to_v1', 'check'], required=True,
                    help='check runs v1 -> v2 -> v1 on every entry and reports differences')
    cc.add_argument('--data_dir', default='./datastore/data', help='Path to datastore/data')
    cc.add_argument('--out_dir', default=None,
                    help='Write <out_dir>/<id>/meta_json-ld_<id>.json (required unless check)')
    cc.add_argument('--source', action='append', help='Only this source (repeatable)')
    cc.add_argument('--etl', action='store_true', help='v1_to_v2: add values from meta_etl')


def dispatch(args: argparse.Namespace) -> int:
    """Run convert_catalog and return a process exit code."""
    logging.basicConfig(level=logging.INFO)
    data_dir = Path(args.data_dir)
    sources = sorted(p.name for p in data_dir.iterdir()
                     if (p / f'meta_json-ld_{p.name}.json').exists()
                     and (not args.source or p.name in args.source))
    if args.direction != 'check' and not args.out_dir:
        logging.error('--out_dir is required for a conversion')
        return 2
    failures = 0
    for source in sources:
        doc = read_json(data_dir / source / f'meta_json-ld_{source}.json')
        try:
            if args.direction == 'check':
                diff = round_trip_diff(doc)
                if diff:
                    failures += 1
                    logging.warning(f'{source}: round trip changes {diff}')
                continue
            etl = read_json(data_dir / source / f'meta_etl_{source}.json') if args.etl else None
            if args.direction == 'v1_to_v2':
                converted = flat_to_v2(doc, etl)
            else:
                converted = v2_to_flat(doc)
        except (ConversionError, KeyError) as e:
            failures += 1
            logging.error(f'{source}: {e!r}')
            continue
        target = Path(args.out_dir) / source
        target.mkdir(parents=True, exist_ok=True)
        (target / f'meta_json-ld_{source}.json').write_text(
            json.dumps(converted, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    logging.info(f'{len(sources)} entries, {failures} with problems')
    return 1 if failures else 0


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    add_subcommands(sub)
    sys.exit(dispatch(parser.parse_args()))
